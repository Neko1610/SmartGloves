#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>
#include <math.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"

#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_log.h"
#include "mqtt_client.h"
#include "nvs.h"
#include "nvs_flash.h"

#include "driver/i2c.h"
#include "driver/uart.h"
#include "esp_adc/adc_oneshot.h"

#include "mpu6050.h"

#define WIFI_SSID "NN"
#define WIFI_PASS "02092003"

#define MQTT_BROKER "mqtt://broker.emqx.io"

#define TOPIC_TRAIN_CMD "glove/train"
#define TOPIC_CLEAR_CMD "glove/clear"
#define TOPIC_RESULT "glove/gesture"
#define TOPIC_RECOGNIZE "glove/recognize"
#define TOPIC_GET_TRAINED "glove/get_trained"
#define TOPIC_TRAINED_LIST "glove/trained_list"



#define I2C_PORT I2C_NUM_0
#define SDA_PIN 6
#define SCL_PIN 7

static const char *TAG = "SMART_GLOVE";
static int recognize_enabled = 0;
/**************** MODEL STRUCT ****************/

typedef struct {
    int flex[5];
    float pitch;
    float roll;
    int trained;
} gesture_t;

static gesture_t model[27];

/**************** NVS STORAGE ****************/

#define NVS_NAMESPACE "glove"

static void save_model()
{
    nvs_handle_t h;
    nvs_open(NVS_NAMESPACE, NVS_READWRITE, &h);
    nvs_set_blob(h, "model", model, sizeof(model));
    nvs_commit(h);
    nvs_close(h);
}

static void load_model()
{
    nvs_handle_t h;
    size_t size = sizeof(model);

    if(nvs_open(NVS_NAMESPACE, NVS_READONLY, &h)==ESP_OK)
    {
        nvs_get_blob(h,"model",model,&size);
        nvs_close(h);
        ESP_LOGI(TAG,"MODEL LOADED");
    }
}

/**************** MQTT ****************/

static esp_mqtt_client_handle_t mqtt_client;

void publish_gesture(char g)
{
    char json[64];

    if(g==' ')
        snprintf(json,sizeof(json),
        "{\"source\":\"glove\",\"gesture\":\"SPACE\"}");
    else
        snprintf(json,sizeof(json),
        "{\"source\":\"glove\",\"gesture\":\"%c\"}",g);

    esp_mqtt_client_publish(
        mqtt_client,
        TOPIC_RESULT,
        json,
        0,
        1,
        0
    );
}

/**************** SENSORS ****************/

static mpu6050_handle_t mpu;
static adc_oneshot_unit_handle_t adc;

static adc_channel_t adc_ch[5] =
{
ADC_CHANNEL_0,
ADC_CHANNEL_1,
ADC_CHANNEL_2,
ADC_CHANNEL_3,
ADC_CHANNEL_4
};

void get_angles(float *pitch,float *roll)
{
    mpu6050_acce_value_t ac;

    mpu6050_get_acce(mpu,&ac);

    *roll=atan2f(ac.acce_y,ac.acce_z)*57.3f;

    *pitch=atanf(-ac.acce_x/
    sqrtf(ac.acce_y*ac.acce_y+ac.acce_z*ac.acce_z))*57.3f;
}

/**************** TRAIN ****************/

void train_letter(char L)
{
    int id=(L==' ')?26:(L-'A');

    int sumF[5]={0};
    float sumPitch=0,sumRoll=0;

    for(int t=0;t<20;t++)
    {
        for(int i=0;i<5;i++)
        {
            int v=0;
            adc_oneshot_read(adc,adc_ch[i],&v);
            sumF[i]+=v;
        }

        float p,r;
        get_angles(&p,&r);

        sumPitch+=p;
        sumRoll+=r;

        vTaskDelay(pdMS_TO_TICKS(50));
    }

    for(int i=0;i<5;i++)
        model[id].flex[i]=sumF[i]/20;

    model[id].pitch=sumPitch/20;
    model[id].roll=sumRoll/20;
    model[id].trained=1;

    save_model();

    ESP_LOGI(TAG,"TRAINED %c",L);
    char msg[2];
msg[0] = L;
msg[1] = '\0';

esp_mqtt_client_publish(
    mqtt_client,
    "glove/trained",
    msg,
    0,
    1,
    0
);
}

/**************** RECOGNIZE ****************/

char recognize_letter()
{
    int f[5];

    for(int i=0;i<5;i++)
        adc_oneshot_read(adc,adc_ch[i],&f[i]);

    float p,r;
    get_angles(&p,&r);

    int best=-1;
    int bestDiff=999999;

    for(int k=0;k<27;k++)
    {
        if(!model[k].trained) continue;

        int diff=0;

        for(int i=0;i<5;i++)
            diff+=abs(f[i]-model[k].flex[i]);

        diff+=abs((int)(p-model[k].pitch))*20;
        diff+=abs((int)(r-model[k].roll))*20;

        if(diff<bestDiff)
        {
            bestDiff=diff;
            best=k;
        }
    }

    if(best<0) return '?';

    if(best==26) return ' ';

    return 'A'+best;
}

/**************** VOTING ****************/

#define VOTE_SIZE 3

char vote_buf[VOTE_SIZE];
int vote_index=0;
char last_sent='?';

char vote_result()
{
    int count[27]={0};

    for(int i=0;i<VOTE_SIZE;i++)
    {
        char c=vote_buf[i];

        if(c==' ') count[26]++;
        else if(c>='A'&&c<='Z')
        count[c-'A']++;
    }

    int best=-1;
    int max=0;

    for(int i=0;i<27;i++)
    {
        if(count[i]>max)
        {
            max=count[i];
            best=i;
        }
    }

    if(best<0) return '?';

    if(best==26) return ' ';

    return 'A'+best;
}
/****************Train Letter***************** */
void send_trained_letters()
{
    char list[128] = "";

    for(int i=0;i<27;i++)
    {
        if(model[i].trained)
        {
            if(i==26)
            {
                strcat(list,"SPACE,");
            }
            else
            {
                char c[3];
                sprintf(c,"%c,", 'A'+i);
                strcat(list,c);
            }
        }
    }

    ESP_LOGI(TAG,"SEND TRAINED LIST: %s",list);

    esp_mqtt_client_publish(
        mqtt_client,
        TOPIC_TRAINED_LIST,
        list,
        0,
        1,
        1
    );
}
/**************** REALTIME TASK ****************/

void recognize_task(void *arg)
{
    while(1)
    {
        if(!recognize_enabled)
        {
            vTaskDelay(pdMS_TO_TICKS(200));
            continue;
        }

        char g = recognize_letter();

        vote_buf[vote_index++] = g;

        if(vote_index >= VOTE_SIZE)
        {
            vote_index = 0;

            char final = vote_result();

            if(final!='?' && final!=last_sent)
            {
                last_sent = final;

                publish_gesture(final);

                ESP_LOGI(TAG,"GESTURE %c",final);

                recognize_enabled = 0; // dừng nhận dạng
            }
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
/**************** WIFI ****************/

static EventGroupHandle_t wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0

static void wifi_event_handler(void *arg,
esp_event_base_t event_base,
int32_t event_id,
void *event_data)
{
    if(event_base==WIFI_EVENT && event_id==WIFI_EVENT_STA_START)
        esp_wifi_connect();

    else if(event_base==WIFI_EVENT && event_id==WIFI_EVENT_STA_DISCONNECTED)
        esp_wifi_connect();

    else if(event_base==IP_EVENT && event_id==IP_EVENT_STA_GOT_IP)
        xEventGroupSetBits(wifi_event_group,WIFI_CONNECTED_BIT);
}

void wifi_init()
{
    nvs_flash_init();

    esp_netif_init();
    esp_event_loop_create_default();

    wifi_event_group=xEventGroupCreate();

    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg=WIFI_INIT_CONFIG_DEFAULT();

    esp_wifi_init(&cfg);

    wifi_config_t wifi_config={};

    strcpy((char*)wifi_config.sta.ssid,WIFI_SSID);
    strcpy((char*)wifi_config.sta.password,WIFI_PASS);

    esp_event_handler_register(WIFI_EVENT,ESP_EVENT_ANY_ID,wifi_event_handler,NULL);
    esp_event_handler_register(IP_EVENT,IP_EVENT_STA_GOT_IP,wifi_event_handler,NULL);

    esp_wifi_set_mode(WIFI_MODE_STA);
    esp_wifi_set_config(WIFI_IF_STA,&wifi_config);

    esp_wifi_start();

    xEventGroupWaitBits(
        wifi_event_group,
        WIFI_CONNECTED_BIT,
        false,
        true,
        portMAX_DELAY
    );
}
static void mqtt_event_handler(void *handler_args,
                               esp_event_base_t base,
                               int32_t event_id,
                               void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;

    switch(event_id)
    {
        case MQTT_EVENT_CONNECTED:

            ESP_LOGI(TAG,"MQTT CONNECTED");

            esp_mqtt_client_subscribe(mqtt_client,TOPIC_TRAIN_CMD,1);
            esp_mqtt_client_subscribe(mqtt_client,TOPIC_CLEAR_CMD,1);
            esp_mqtt_client_subscribe(mqtt_client,TOPIC_RECOGNIZE,1);

            esp_mqtt_client_subscribe(mqtt_client,TOPIC_GET_TRAINED,1);

        break; 

        case MQTT_EVENT_DATA:

            char topic[64]={0};
            char data[64]={0};

            memcpy(topic,event->topic,event->topic_len);
            memcpy(data,event->data,event->data_len);

            ESP_LOGI(TAG,"TOPIC %s",topic);
            ESP_LOGI(TAG,"DATA %s",data);

            if(strcmp(topic,TOPIC_TRAIN_CMD)==0)
            {
                char L=data[0];

                train_letter(L);
            }
            else if(strcmp(topic,TOPIC_RECOGNIZE)==0)
            {
                recognize_enabled = 1;

                vote_index = 0;

                ESP_LOGI(TAG,"START RECOGNIZE");
            }
        
            else if(strcmp(topic, "glove/get_trained")==0)
            {
                ESP_LOGI(TAG,"REQUEST TRAINED LIST");

                send_trained_letters();
            }
          else if(strcmp(topic,TOPIC_CLEAR_CMD)==0)
        {
            /// CLEAR ALL
            if(strstr(data,"ALL") != NULL)
            {
                for(int i=0;i<27;i++)
                {
                    memset(&model[i],0,sizeof(gesture_t));
                }

                save_model();

                ESP_LOGI(TAG,"CLEARED ALL");

                send_trained_letters();
            }

            /// CLEAR 1 LETTER
            else
            {
                char L;

                if(data[0]=='"')
                    L=data[1];
                else
                    L=data[0];

                int id=(L==' ')?26:(L-'A');

                memset(&model[id],0,sizeof(gesture_t));

                save_model();

                ESP_LOGI(TAG,"CLEARED %c",L);

                send_trained_letters();
            }
        }

        break;

        default:
        break;
    }
}
/**************** INIT ****************/

void init_all()
{
    uart_config_t uart_config={
        .baud_rate=115200,
        .data_bits=UART_DATA_8_BITS,
        .parity=UART_PARITY_DISABLE,
        .stop_bits=UART_STOP_BITS_1
    };

    uart_param_config(UART_NUM_0,&uart_config);
    uart_driver_install(UART_NUM_0,256,0,0,NULL,0);

    i2c_config_t i2c_config={
        .mode=I2C_MODE_MASTER,
        .sda_io_num=SDA_PIN,
        .scl_io_num=SCL_PIN,
        .master.clk_speed=400000
    };
    
    i2c_param_config(I2C_PORT,&i2c_config);
    i2c_driver_install(I2C_PORT,i2c_config.mode,0,0,0);

    mpu=mpu6050_create(I2C_PORT,MPU6050_I2C_ADDRESS);

    adc_oneshot_unit_init_cfg_t uc={.unit_id=ADC_UNIT_1};
    adc_oneshot_new_unit(&uc,&adc);

    adc_oneshot_chan_cfg_t cfg={
        .atten=ADC_ATTEN_DB_12,
        .bitwidth=ADC_BITWIDTH_DEFAULT
    };

    for(int i=0;i<5;i++)
        adc_oneshot_config_channel(adc,adc_ch[i],&cfg);

       esp_mqtt_client_config_t m={
    .broker.address.uri=MQTT_BROKER
};

        mqtt_client=esp_mqtt_client_init(&m);

        esp_mqtt_client_register_event(
            mqtt_client,
            ESP_EVENT_ANY_ID,
            mqtt_event_handler,
            NULL
        );

        esp_mqtt_client_start(mqtt_client);
    }

/**************** MAIN ****************/

void app_main(void)
{
    ESP_LOGI(TAG, "SMART GLOVE START");

    wifi_init();

    vTaskDelay(pdMS_TO_TICKS(500));

    init_all();
    load_model();

    ESP_LOGI(TAG, "MODEL LOADED");

    xTaskCreate(
        recognize_task,
        "recognize_task",
        4096,
        NULL,
        5,
        NULL
    );
}