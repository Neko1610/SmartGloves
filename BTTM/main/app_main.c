/************************************************************
 * SMART GLOVE – ESP32-C3 (FINAL VERSION)
 * Save/Load MODEL to NVS (NO LOSS after RESET)
 * Support A–Z + SPACE
 * MQTT TRAIN / RECOGNIZE / CLEAR
 ************************************************************/

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

#define TOPIC_TRAIN_CMD      "glove/train"
#define TOPIC_CLEAR_CMD      "glove/clear"
#define TOPIC_RECOG_CMD      "glove/recognize"
#define TOPIC_SENSOR_FINAL   "glove/sensor_final"

#define TOPIC_TRAIN_RESULT   "glove/train_result"
#define TOPIC_RECOG_RESULT   "glove/recognize_result"

#define I2C_PORT I2C_NUM_0
#define SDA_PIN 6
#define SCL_PIN 7

static const char *TAG = "SMART_GLOVE";

/************************************************************
 * MODEL STRUCT (A–Z + SPACE)
 ************************************************************/
typedef struct {
    int flex[5];
    float pitch;
    float roll;
    int trained;
} gesture_t;

static gesture_t model[27];   // 0–25: A–Z, 26 = SPACE

/************************************************************
 * NVS SAVE / LOAD MODEL
 ************************************************************/
#define NVS_NAMESPACE "glove"

static esp_err_t save_model_to_nvs()
{
    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &h);
    if (err != ESP_OK) return err;

    err = nvs_set_blob(h, "model_blob", model, sizeof(model));
    if (err == ESP_OK) err = nvs_commit(h);

    nvs_close(h);
    ESP_LOGI(TAG, "MODEL SAVED TO NVS (%d bytes)", sizeof(model));
    return err;
}

static esp_err_t load_model_from_nvs()
{
    nvs_handle_t h;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READONLY, &h);
    if (err != ESP_OK) return err;

    size_t size = sizeof(model);
    err = nvs_get_blob(h, "model_blob", model, &size);

    nvs_close(h);
    if (err == ESP_OK)
        ESP_LOGI(TAG, "MODEL LOADED FROM NVS (%d bytes)", size);

    return err;
}

/************************************************************
 * MQTT + SENSOR FUNCTIONS
 ************************************************************/
static esp_mqtt_client_handle_t mqtt_client = NULL;
static EventGroupHandle_t wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0

static mpu6050_handle_t mpu;
static adc_oneshot_unit_handle_t adc;

static adc_channel_t adc_ch[5] = {
    ADC_CHANNEL_0, ADC_CHANNEL_1,
    ADC_CHANNEL_2, ADC_CHANNEL_3,
    ADC_CHANNEL_4
};

/************************************************************
 * PUBLISH JSON
 ************************************************************/
void publish_json(const char *topic, const char *json)
{
    esp_mqtt_client_publish(mqtt_client, topic, json, 0, 1, 0);
    ESP_LOGI(TAG, "PUBLISH %s → %s", topic, json);
}

/************************************************************
 * GET ANGLES
 ************************************************************/
void get_angles(float *pitch, float *roll)
{
    mpu6050_acce_value_t ac;
    mpu6050_get_acce(mpu, &ac);

    *roll  = atan2f(ac.acce_y, ac.acce_z) * 57.3f;
    *pitch = atanf(-ac.acce_x /
                    sqrtf(ac.acce_y*ac.acce_y + ac.acce_z*ac.acce_z)) * 57.3f;
}

/************************************************************
 * TRAIN ONE CHARACTER (A–Z, SPACE)
 ************************************************************/
void start_train_for(char L)
{
    int id;

    if (L == ' ') id = 26;
    else id = L - 'A';

    ESP_LOGI(TAG, "TRAINING %s", (L==' ' ? "SPACE" : (char[2]){L,0}));

    int sumF[5] = {0};
    float sumPitch = 0, sumRoll = 0;

    for (int t = 0; t < 20; t++)
    {
        for (int i = 0; i < 5; i++) {
            int v = 0; adc_oneshot_read(adc, adc_ch[i], &v);
            sumF[i] += v;
        }

        float p,r;
        get_angles(&p,&r);
        sumPitch += p;
        sumRoll  += r;

        vTaskDelay(pdMS_TO_TICKS(50));
    }

    for (int i = 0; i < 5; i++)
        model[id].flex[i] = sumF[i] / 20;

    model[id].pitch = sumPitch / 20;
    model[id].roll  = sumRoll  / 20;
    model[id].trained = 1;

    save_model_to_nvs();   // 🔥 SAVE MODEL AFTER EACH TRAIN

    char json[128];
    if (L == ' ')
        snprintf(json, sizeof(json),
            "{\"letter\":\"SPACE\"}");
    else
        snprintf(json, sizeof(json),
            "{\"letter\":\"%c\"}", L);

    publish_json(TOPIC_TRAIN_RESULT, json);
}

void train_task(void *arg)
{
    char L = ((char*)arg)[0];
    free(arg);
    start_train_for(L);
    vTaskDelete(NULL);
}

/************************************************************
 * CLEAR MODEL ENTRY
 ************************************************************/
void clear_letter(char L)
{
    int id = (L==' ') ? 26 : L-'A';
    memset(&model[id], 0, sizeof(gesture_t));

    save_model_to_nvs();  // 🔥 SAVE AFTER CLEAR

    char json[32];
    if (L == ' ')
        snprintf(json, sizeof(json), "{\"clear\":\"SPACE\"}");
    else
        snprintf(json, sizeof(json), "{\"clear\":\"%c\"}", L);

    publish_json(TOPIC_TRAIN_RESULT, json);
}

/************************************************************
 * RECOGNIZE INSTANT
 ************************************************************/
char recognize_letter()
{
    int f[5];
    for (int i = 0; i < 5; i++)
        adc_oneshot_read(adc, adc_ch[i], &f[i]);

    float p,r;
    get_angles(&p,&r);

    int best=-1;
    int bestDiff = 9999999;

    for (int k = 0; k < 27; k++)
    {
        if (!model[k].trained) continue;

        int diff = 0;

        for (int i = 0; i < 5; i++)
            diff += abs(f[i] - model[k].flex[i]);

        diff += abs((int)(p - model[k].pitch))*20;
        diff += abs((int)(r - model[k].roll))*20;

        if (diff < bestDiff) { bestDiff = diff; best = k; }
    }

    if (best < 0) return '?';
    if (best == 26) return ' ';
    return (char)('A' + best);
}

/************************************************************
 * MQTT EVENT HANDLER
 ************************************************************/
static void mqtt_event_cb(void *handler_args,
                           esp_event_base_t base,
                           int32_t id,
                           void *event_data)
{
    esp_mqtt_event_handle_t e = event_data;

    switch(id)
    {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "MQTT CONNECTED");
            esp_mqtt_client_subscribe(mqtt_client, TOPIC_TRAIN_CMD, 1);
            esp_mqtt_client_subscribe(mqtt_client, TOPIC_CLEAR_CMD, 1);
            esp_mqtt_client_subscribe(mqtt_client, TOPIC_RECOG_CMD, 1);
            break;

        case MQTT_EVENT_DATA:
        {
            char payload[64]={0};
            memcpy(payload, e->data, e->data_len);

            char L = payload[0];

            if (strcmp(e->topic, TOPIC_TRAIN_CMD)==0) {
                char *arg = malloc(2);
                arg[0] = L; arg[1] = 0;
                xTaskCreate(train_task,"train_task",6000,arg,5,NULL);
            }
            else if (strcmp(e->topic, TOPIC_CLEAR_CMD)==0) {
                clear_letter(L);
            }
            else if (strcmp(e->topic, TOPIC_RECOG_CMD)==0) {
                char g = recognize_letter();

                char json[32];
                if (g==' ')
                    snprintf(json,sizeof(json),"{\"gesture\":\" \"}");
                else
                    snprintf(json,sizeof(json),"{\"gesture\":\"%c\"}",g);

                publish_json(TOPIC_RECOG_RESULT, json);
            }
        }
        break;
    }
}

/************************************************************
 * WIFI INIT
 ************************************************************/
static void wifi_event_handler(void *arg,
                               esp_event_base_t base,
                               int32_t id,
                               void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START)
        esp_wifi_connect();

    else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED)
        esp_wifi_connect();

    else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP)
        xEventGroupSetBits(wifi_event_group, WIFI_CONNECTED_BIT);
}

void wifi_init()
{
    nvs_flash_init();
    esp_netif_init();
    esp_event_loop_create_default();

    wifi_event_group = xEventGroupCreate();
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_wifi_init(&cfg);

    wifi_config_t wc = {0};
    strcpy((char*)wc.sta.ssid, WIFI_SSID);
    strcpy((char*)wc.sta.password, WIFI_PASS);
    wc.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;
    wc.sta.pmf_cfg.required = false;
    wc.sta.pmf_cfg.capable  = true;

    esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, wifi_event_handler, NULL);
    esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, wifi_event_handler, NULL);

    esp_wifi_set_mode(WIFI_MODE_STA);
    esp_wifi_set_config(WIFI_IF_STA, &wc);
    esp_wifi_start();

    ESP_LOGI(TAG, "WAITING FOR IP...");
    xEventGroupWaitBits(wifi_event_group, WIFI_CONNECTED_BIT, false, true, portMAX_DELAY);
}

/************************************************************
 * INIT SENSORS + MQTT
 ************************************************************/
void init_all()
{
    uart_config_t u = {
        .baud_rate=115200,
        .data_bits=UART_DATA_8_BITS,
        .parity=UART_PARITY_DISABLE,
        .stop_bits=UART_STOP_BITS_1
    };
    uart_param_config(UART_NUM_0,&u);
    uart_driver_install(UART_NUM_0,256,0,0,NULL,0);

    i2c_config_t c={
        .mode=I2C_MODE_MASTER,
        .sda_io_num=SDA_PIN,
        .scl_io_num=SCL_PIN,
        .master.clk_speed=400000
    };
    i2c_param_config(I2C_PORT,&c);
    i2c_driver_install(I2C_PORT,c.mode,0,0,0);

    mpu = mpu6050_create(I2C_PORT, MPU6050_I2C_ADDRESS);
    mpu6050_config(mpu, ACCE_FS_4G, GYRO_FS_500DPS);

    adc_oneshot_unit_init_cfg_t uc={ .unit_id=ADC_UNIT_1 };
    adc_oneshot_new_unit(&uc,&adc);

    adc_oneshot_chan_cfg_t cfg={
        .atten=ADC_ATTEN_DB_12,
        .bitwidth=ADC_BITWIDTH_DEFAULT
    };
    for (int i=0;i<5;i++)
        adc_oneshot_config_channel(adc,adc_ch[i],&cfg);

    esp_mqtt_client_config_t m={
        .broker.address.uri="mqtt://broker.hivemq.com"
    };
    mqtt_client = esp_mqtt_client_init(&m);
    esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_cb, NULL);
    esp_mqtt_client_start(mqtt_client);
}

/************************************************************
 * MAIN
 ************************************************************/
void app_main(void)
{
    ESP_LOGI(TAG, "=== SMART GLOVE START ===");

    wifi_init();
    vTaskDelay(300 / portTICK_PERIOD_MS);

    ESP_LOGI(TAG, "Loading model...");
    if (load_model_from_nvs() == ESP_OK)
        ESP_LOGI(TAG, "MODEL RESTORED");
    else
        ESP_LOGW(TAG, "NO MODEL FOUND");

    init_all();

    while (1) vTaskDelay(1000 / portTICK_PERIOD_MS);
}
