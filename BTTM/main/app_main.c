#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>
#include <stdbool.h>
#include <math.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"

#include "esp_https_ota.h"
#include "esp_http_client.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_err.h"
#include "esp_log.h"
#include "mqtt_client.h"
#include "nvs.h"
#include "nvs_flash.h"

#include "driver/i2c.h"
#include "driver/uart.h"
#include "esp_adc/adc_oneshot.h"
adc_oneshot_unit_handle_t adc;

adc_channel_t adc_ch[5] = {
    ADC_CHANNEL_0,
    ADC_CHANNEL_1,
    ADC_CHANNEL_2,
    ADC_CHANNEL_3,
    ADC_CHANNEL_4};
#include "mpu6050.h"
void send_trained_letters();
#define WIFI_SSID "NN"
#define WIFI_PASS "02092003"

#define MQTT_BROKER "mqtt://broker.emqx.io:1883"

#define TOPIC_TRAIN_CMD "glove/train"
#define TOPIC_CLEAR_CMD "glove/clear"
#define TOPIC_RESULT "glove/gesture"
#define TOPIC_RECOGNIZE "glove/recognize"
#define TOPIC_GET_TRAINED "glove/get_trained"
#define TOPIC_TRAINED_LIST "glove/trained_list"
#define TOPIC_OTA "glove/ota"
#define OTA_URL "http://10.15.20.234:8000/BTTM.bin"

#define I2C_PORT I2C_NUM_0
#define SDA_PIN 6
#define SCL_PIN 7
#define I2C_FREQ_HZ 400000
#define RAD_TO_DEG 57.2957795f
#define ANGLE_ALPHA 0.6f

static const char *TAG = "SMART_GLOVE";
static int recognize_enabled = 0;

#define WINDOW_SIZE 10
#define STABLE_THRESHOLD 6

static char buffer[WINDOW_SIZE];
static int buf_index = 0;
static int buf_count = 0;

static char last_gesture = '?';
float g_pitch = 0;
float g_roll = 0;
int demo_mode = 1;
char demo_sequence[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
int demo_index = 0;

/**************** MODEL STRUCT ****************/
typedef struct
{
    float flex[5];
    float pitch;
    float roll;
    int trained;
} gesture_t;

static gesture_t model[27];

// calibration
float f_min[5];
float f_max[5];
/*************calibrate************** */
void calibrate_flex()
{
    ESP_LOGI(TAG, "CALIB: KEEP HAND OPEN");

    // reset
    for (int i = 0; i < 5; i++)
    {
        f_min[i] = 1.0f;
        f_max[i] = 0.0f;
    }

    // 🔥 đo MIN (tay duỗi)
    for (int t = 0; t < 50; t++)
    {
        for (int i = 0; i < 5; i++)
        {
            int v;
            adc_oneshot_read(adc, adc_ch[i], &v);

            float f = (float)v / 4095.0f;

            if (f < f_min[i])
                f_min[i] = f;
        }

        vTaskDelay(pdMS_TO_TICKS(20));
    }

    ESP_LOGI(TAG, "CALIB: NOW CLOSE HAND");
    vTaskDelay(pdMS_TO_TICKS(2000)); // cho bạn nắm tay

    // 🔥 đo MAX (nắm tay)
    for (int t = 0; t < 50; t++)
    {
        for (int i = 0; i < 5; i++)
        {
            int v;
            adc_oneshot_read(adc, adc_ch[i], &v);

            float f = (float)v / 4095.0f;

            if (f > f_max[i])
                f_max[i] = f;
        }

        vTaskDelay(pdMS_TO_TICKS(20));
    }

    ESP_LOGI(TAG, "CALIB DONE");

    for (int i = 0; i < 5; i++)
    {
        ESP_LOGI(TAG, "F%d min=%.2f max=%.2f", i, f_min[i], f_max[i]);
    }
}
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

    if (nvs_open(NVS_NAMESPACE, NVS_READONLY, &h) == ESP_OK)
    {
        nvs_get_blob(h, "model", model, &size);
        nvs_close(h);
        ESP_LOGI(TAG, "MODEL LOADED");
    }
}
void ota_task(void *pvParameter)
{
    ESP_LOGI(TAG, "START OTA...");

    esp_http_client_config_t http_config = {
        .url = OTA_URL,
        .timeout_ms = 10000,
    };

    esp_https_ota_config_t ota_config = {
        .http_config = &http_config,
    };

    esp_err_t ret = esp_https_ota(&ota_config);

    if (ret == ESP_OK)
    {
        ESP_LOGI(TAG, "OTA SUCCESS -> RESTART");
        esp_restart();
    }
    else
    {
        ESP_LOGE(TAG, "OTA FAILED");
    }

    vTaskDelete(NULL);
}

void reset_buffer()
{
    for (int i = 0; i < WINDOW_SIZE; i++)
    {
        buffer[i] = '?';
    }
    buf_index = 0;
    buf_count = 0;
}

void add_raw(char raw)
{
    buffer[buf_index] = raw;
    buf_index = (buf_index + 1) % WINDOW_SIZE;

    if (buf_count < WINDOW_SIZE)
    {
        buf_count++;
    }
}

char get_stable_gesture()
{
    if (buf_count < WINDOW_SIZE)
        return '?';

    int count[256] = {0};

    for (int i = 0; i < WINDOW_SIZE; i++)
    {
        if (buffer[i] != '?')
        {
            unsigned char c = (unsigned char)buffer[i];
            count[c]++;
        }
    }

    int max = 0;
    char result = '?';

    for (int i = 0; i < 256; i++)
    {
        if (count[i] > max)
        {
            max = count[i];
            result = (char)i;
        }
    }

    if (max >= STABLE_THRESHOLD)
        return result;

    return '?';
}
/**************** MQTT ****************/

static esp_mqtt_client_handle_t mqtt_client;

void publish_gesture(
    char g,
    float pitch,
    float roll)
{
    char json[128];

    if (g == ' ')
    {
        snprintf(
            json,
            sizeof(json),
            "{\"source\":\"glove\",\"gesture\":\"SPACE\",\"pitch\":%.1f,\"roll\":%.1f}",
            pitch,
            roll);
    }
    else
    {
        snprintf(
            json,
            sizeof(json),
            "{\"source\":\"glove\",\"gesture\":\"%c\",\"pitch\":%.1f,\"roll\":%.1f}",
            g,
            pitch,
            roll);
    }

    esp_mqtt_client_publish(
        mqtt_client,
        TOPIC_RESULT,
        json,
        0,
        1,
        0);
}

/**************** SENSORS ****************/

static mpu6050_handle_t mpu;
static bool mpu_ready = false;
static uint8_t mpu_addr = 0;

static esp_err_t i2c_master_init(void)
{
    i2c_config_t i2c_config = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = SDA_PIN,
        .scl_io_num = SCL_PIN,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = I2C_FREQ_HZ,
    };

    esp_err_t ret = i2c_param_config(I2C_PORT, &i2c_config);
    if (ret != ESP_OK)
    {
        ESP_LOGE(TAG, "I2C param config failed: %s", esp_err_to_name(ret));
        return ret;
    }

    ret = i2c_driver_install(I2C_PORT, i2c_config.mode, 0, 0, 0);
    if (ret != ESP_OK)
    {
        ESP_LOGE(TAG, "I2C driver install failed: %s", esp_err_to_name(ret));
        return ret;
    }

    ESP_LOGI(TAG, "I2C ready: SDA=GPIO%d SCL=GPIO%d CLK=%dHz", SDA_PIN, SCL_PIN, I2C_FREQ_HZ);
    return ESP_OK;
}

static void i2c_scan(void)
{
    ESP_LOGI(TAG, "I2C scan start");

    int found = 0;
    for (uint8_t addr = 1; addr < 127; addr++)
    {
        i2c_cmd_handle_t cmd = i2c_cmd_link_create();
        i2c_master_start(cmd);
        i2c_master_write_byte(cmd, (addr << 1) | I2C_MASTER_WRITE, true);
        i2c_master_stop(cmd);

        esp_err_t ret = i2c_master_cmd_begin(I2C_PORT, cmd, pdMS_TO_TICKS(100));
        i2c_cmd_link_delete(cmd);

        if (ret == ESP_OK)
        {
            ESP_LOGI(TAG, "I2C device found at 0x%02X", addr);
            found++;
        }
    }

    if (found == 0)
        ESP_LOGW(TAG, "I2C scan found no devices");

    ESP_LOGI(TAG, "I2C scan done, found=%d", found);
}

static esp_err_t mpu6050_init_sensor(void)
{
    const uint8_t addresses[] = {
        MPU6050_I2C_ADDRESS,
        MPU6050_I2C_ADDRESS_1,
    };

    mpu_ready = false;
    mpu_addr = 0;

    for (int i = 0; i < 2; i++)
    {
        uint8_t addr = addresses[i];
        ESP_LOGI(TAG, "Trying MPU6050 at 0x%02X", addr);

        if (mpu != NULL)
        {
            mpu6050_delete(mpu);
            mpu = NULL;
        }

        mpu = mpu6050_create(I2C_PORT, addr);
        if (mpu == NULL)
        {
            ESP_LOGE(TAG, "MPU6050 create failed at 0x%02X", addr);
            continue;
        }

        esp_err_t ret = mpu6050_wake_up(mpu);
        if (ret != ESP_OK)
        {
            ESP_LOGW(TAG, "MPU6050 wake failed at 0x%02X: %s", addr, esp_err_to_name(ret));
            continue;
        }

        vTaskDelay(pdMS_TO_TICKS(100));

        ret = mpu6050_config(mpu, ACCE_FS_2G, GYRO_FS_250DPS);
        if (ret != ESP_OK)
        {
            ESP_LOGW(TAG, "MPU6050 config failed at 0x%02X: %s", addr, esp_err_to_name(ret));
            continue;
        }

        uint8_t device_id = 0;
        ret = mpu6050_get_deviceid(mpu, &device_id);
        if (ret != ESP_OK)
        {
            ESP_LOGW(TAG, "MPU6050 WHO_AM_I failed at 0x%02X: %s", addr, esp_err_to_name(ret));
            continue;
        }

        ESP_LOGI(TAG, "MPU6050 WHO_AM_I at 0x%02X = 0x%02X", addr, device_id);

        if (device_id != 0x68 && device_id != 0x70)
        {
            ESP_LOGW(TAG, "Unknown MPU id at 0x%02X: 0x%02X", addr, device_id);
            continue;
        }

        mpu_ready = true;
        mpu_addr = addr;
        ESP_LOGI(TAG, "MPU6050 initialized at 0x%02X", mpu_addr);
        return ESP_OK;
    }

    ESP_LOGE(TAG, "MPU6050 init failed at both 0x68 and 0x69");
    return ESP_FAIL;
}

esp_err_t get_angles(float *pitch, float *roll)
{
    if (!mpu_ready || mpu == NULL)
    {
        ESP_LOGW(TAG, "MPU6050 is not ready");
        return ESP_FAIL;
    }

    mpu6050_acce_value_t ac = {0};
    esp_err_t ret = mpu6050_get_acce(mpu, &ac);
    if (ret != ESP_OK)
    {
        ESP_LOGE(TAG, "MPU accel read failed: %s", esp_err_to_name(ret));
        return ret;
    }

    float denom = sqrtf(ac.acce_y * ac.acce_y + ac.acce_z * ac.acce_z);
    if (denom < 0.000001f)
        denom = 0.000001f;

    float raw_roll = atan2f(ac.acce_y, ac.acce_z) * RAD_TO_DEG;
    float raw_pitch = atanf(-ac.acce_x / denom) * RAD_TO_DEG;

    // 🔥 FIX TRỤC (QUAN TRỌNG)
    raw_roll = -raw_roll;
    static bool initialized = false;
    static float last_roll = 0;
    static float last_pitch = 0;

    if (!initialized)
    {
        *roll = raw_roll;
        *pitch = raw_pitch;
        initialized = true;
    }
    else
    {
        *roll = ANGLE_ALPHA * last_roll + (1.0f - ANGLE_ALPHA) * raw_roll;
        *pitch = ANGLE_ALPHA * last_pitch + (1.0f - ANGLE_ALPHA) * raw_pitch;
    }

    last_roll = *roll;
    last_pitch = *pitch;

    ESP_LOGI(TAG, "MPU ax=%.3f ay=%.3f az=%.3f roll=%.2f pitch=%.2f",
             ac.acce_x, ac.acce_y, ac.acce_z, *roll, *pitch);

    return ESP_OK;
}
/**************** TRAIN ****************/

void train_letter(char L)
{
    int id = (L == ' ') ? 26 : (L - 'A');

    float totalF[5] = {0};
    float totalPitch = 0;
    float totalRoll = 0;

    int rounds = 5;      // train 5 lần
    int samples = 40;    // mỗi lần lấy 40 mẫu

    ESP_LOGI(TAG, "=== TRAIN %c START ===", L);

    for (int r = 0; r < rounds; r++)
    {
        ESP_LOGI(TAG, "TRAIN ROUND %d/%d", r + 1, rounds);

        float sumF[5] = {0};
        float sumPitch = 0;
        float sumRoll = 0;
        int angle_samples = 0;

        for (int t = 0; t < samples; t++)
        {
            // ===== FLEX =====
            for (int i = 0; i < 5; i++)
            {
                int v = 0;
                adc_oneshot_read(adc, adc_ch[i], &v);

                float raw = (float)v / 4095.0f;

                float f = (raw - f_min[i]) /
                          (f_max[i] - f_min[i] + 0.001f);

                if (f < 0)
                    f = 0;

                if (f > 1)
                    f = 1;

                sumF[i] += f;
            }

            // ===== MPU =====
            float p, rr;

            if (get_angles(&p, &rr) == ESP_OK)
            {
                sumPitch += p;
                sumRoll += rr;
                angle_samples++;
            }

            vTaskDelay(pdMS_TO_TICKS(30));
        }

        // ===== average round =====
        for (int i = 0; i < 5; i++)
        {
            totalF[i] += sumF[i] / samples;
        }

        if (angle_samples > 0)
        {
            totalPitch += sumPitch / angle_samples;
            totalRoll += sumRoll / angle_samples;
        }

        ESP_LOGI(TAG,
                 "ROUND %d DONE",
                 r + 1);

        // nghỉ chút để đổi tư thế tay
        vTaskDelay(pdMS_TO_TICKS(1000));
    }

    // ===== final average =====
    for (int i = 0; i < 5; i++)
    {
        model[id].flex[i] = totalF[i] / rounds;
    }

    model[id].pitch = totalPitch / rounds;
    model[id].roll = totalRoll / rounds;

    model[id].trained = 1;

    ESP_LOGI(TAG,
             "FINAL TRAINED %c | f=[%.2f %.2f %.2f %.2f %.2f] p=%.1f r=%.1f",
             L,
             model[id].flex[0],
             model[id].flex[1],
             model[id].flex[2],
             model[id].flex[3],
             model[id].flex[4],
             model[id].pitch,
             model[id].roll);
}
/**************** RECOGNIZE ****************/
char recognize_letter()
{
    float f[5] = {0};

    // ===== FLEX: lấy trung bình =====
    for (int t = 0; t < 4; t++)   // 10 -> 4
    {
        for (int i = 0; i < 5; i++)
        {
            int v = 0;
            adc_oneshot_read(adc, adc_ch[i], &v);

            float raw = (float)v / 4095.0f;

            float denom = (f_max[i] - f_min[i]);
            if (denom < 0.01f)
                denom = 0.01f;

            float val = (raw - f_min[i]) / denom;

            if (val < 0)
                val = 0;
            if (val > 1)
                val = 1;

            f[i] += val;
        }

        vTaskDelay(pdMS_TO_TICKS(2)); // 5 -> 2
    }

    for (int i = 0; i < 5; i++)
        f[i] /= 4.0f;

    ESP_LOGI("FLEX", "f=%.2f %.2f %.2f %.2f %.2f",
             f[0], f[1], f[2], f[3], f[4]);

    // ===== MPU: average =====
    float sum_p = 0, sum_r = 0;
    int cnt = 0;

    for (int i = 0; i < 5; i++) // 15 -> 5
    {
        float p_tmp, r_tmp;

        if (get_angles(&p_tmp, &r_tmp) == ESP_OK)
        {
            sum_p += p_tmp;
            sum_r += r_tmp;
            cnt++;
        }

        vTaskDelay(pdMS_TO_TICKS(2)); // 10 -> 2
    }

    if (cnt == 0)
        return '?';

    float p = sum_p / cnt;
    float r = sum_r / cnt;

    ESP_LOGI("MPU_AVG", "p=%.1f r=%.1f", p, r);

    g_pitch = p;
    g_roll = r;

    // ===== chống rung =====
    static float last_p = 0, last_r = 0;

    if (fabsf(p - last_p) > 15.0f || fabsf(r - last_r) > 15.0f)
    {
        last_p = p;
        last_r = r;
        return '?';
    }

    last_p = p;
    last_r = r;

    // ===== so sánh =====
    float bestDiff = 1e9f;
    int best = -1;

    for (int k = 0; k < 27; k++)
    {
        if (!model[k].trained)
            continue;

        float diff = 0;

        // FLEX
        for (int i = 0; i < 5; i++)
        {
            float d = f[i] - model[k].flex[i];
            diff += d * d * 5.0f;
        }

        // MPU
        float dp = p - model[k].pitch;
        float dr = r - model[k].roll;

        diff += dp * dp * 0.015f;
        diff += dr * dr * 0.015f;

        if (diff < bestDiff)
        {
            bestDiff = diff;
            best = k;
        }
    }

    ESP_LOGI("RESULT", "best=%d diff=%.3f", best, bestDiff);

    // ===== threshold =====
    if (bestDiff > 8.0f) // 5 -> 8
        return '?';

    if (best < 0)
        return '?';

    if (best == 26)
        return ' ';

    return 'A' + best;
}
/**************** VOTING ****************/

#define VOTE_SIZE 5

char vote_buf[VOTE_SIZE];
int vote_index = 0;
char last_sent = '?';

char vote_result()
{
    int count[27] = {0};
    int valid = 0;

    for (int i = 0; i < VOTE_SIZE; i++)
    {
        char c = vote_buf[i];

        if (c == '?')
            continue; // 🔥 bỏ nhiễu

        valid++;

        if (c == ' ')
            count[26]++;
        else if (c >= 'A' && c <= 'Z')
            count[c - 'A']++;
    }

    // ❌ nếu quá ít dữ liệu thì bỏ
    if (valid < VOTE_SIZE / 2)
        return '?';

    int best = -1;
    int max = 0;

    for (int i = 0; i < 27; i++)
    {
        if (count[i] > max)
        {
            max = count[i];
            best = i;
        }
    }

    // 🔥 threshold (quan trọng nhất)
    if (max < (VOTE_SIZE / 2 + 1))
        return '?';

    if (best < 0)
        return '?';

    if (best == 26)
        return ' ';

    return 'A' + best;
}
/****************Train Letter***************** */
void send_trained_letters()
{
    char list[128] = "";

    for (int i = 0; i < 27; i++)
    {
        if (model[i].trained)
        {
            if (i == 26)
            {
                strcat(list, "SPACE,");
            }
            else
            {
                char c[3];
                sprintf(c, "%c,", 'A' + i);
                strcat(list, c);
            }
        }
    }

    ESP_LOGI(TAG, "SEND TRAINED LIST: %s", list);

    esp_mqtt_client_publish(
        mqtt_client,
        TOPIC_TRAINED_LIST,
        list,
        0,
        1,
        1);
}
/**************** REALTIME TASK ****************/

void recognize_task(void *arg)
{
    static char last_detect = '?';
    static int stable_count = 0;

    while (1)
    {
        if (!recognize_enabled)
        {
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        char g = recognize_letter();
        ESP_LOGI(TAG, "RAW: %c", g);

        if (g == '?')
        {
            vTaskDelay(pdMS_TO_TICKS(40));
            continue;
        }

        // 🔥 check ổn định
        if (g == last_detect)
        {
            stable_count++;
        }
        else
        {
            stable_count = 0;
            last_detect = g;
        }

        if (stable_count < 3)
        {
            vTaskDelay(pdMS_TO_TICKS(40));
            continue;
        }

        char final = g;

        // // 🔥 DEMO MODE: ép theo thứ tự
        // if (demo_mode)
        // {
        //     char expected = demo_sequence[demo_index];

        //     if (final != expected)
        //     {
        //         ESP_LOGI(TAG, "WAITING FOR %c", expected);
        //         vTaskDelay(pdMS_TO_TICKS(40));
        //         continue;
        //     }

        //     demo_index++;

        //     if (demo_index >= 26)
        //         demo_index = 0;
        // }

        if (final != last_sent)
        {
            last_sent = final;

            publish_gesture(
                final,
                g_pitch,
                g_roll);
            ESP_LOGI(TAG, "GESTURE %c", final);

            recognize_enabled = 0;
            stable_count = 0;
        }

        vTaskDelay(pdMS_TO_TICKS(40));
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
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START)
        esp_wifi_connect();

    else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED)
        esp_wifi_connect();

    else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP)
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

    wifi_config_t wifi_config = {};

    strcpy((char *)wifi_config.sta.ssid, WIFI_SSID);
    strcpy((char *)wifi_config.sta.password, WIFI_PASS);

    esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, wifi_event_handler, NULL);
    esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, wifi_event_handler, NULL);

    esp_wifi_set_mode(WIFI_MODE_STA);
    esp_wifi_set_config(WIFI_IF_STA, &wifi_config);

    esp_wifi_start();

    xEventGroupWaitBits(
        wifi_event_group,
        WIFI_CONNECTED_BIT,
        false,
        true,
        portMAX_DELAY);
}
static void mqtt_event_handler(void *handler_args,
                               esp_event_base_t base,
                               int32_t event_id,
                               void *event_data)
{
    esp_mqtt_event_handle_t event = event_data;

    switch (event_id)
    {
    case MQTT_EVENT_CONNECTED:

        ESP_LOGI(TAG, "MQTT CONNECTED");
        esp_mqtt_client_subscribe(mqtt_client, TOPIC_OTA, 1);
        esp_mqtt_client_subscribe(mqtt_client, TOPIC_TRAIN_CMD, 1);
        esp_mqtt_client_subscribe(mqtt_client, TOPIC_CLEAR_CMD, 1);
        esp_mqtt_client_subscribe(mqtt_client, TOPIC_RECOGNIZE, 1);

        esp_mqtt_client_subscribe(mqtt_client, TOPIC_GET_TRAINED, 1);

        break;

    case MQTT_EVENT_DATA:

        char topic[64] = {0};
        char data[64] = {0};

        memcpy(topic, event->topic, event->topic_len);
        memcpy(data, event->data, event->data_len);

        ESP_LOGI(TAG, "TOPIC %s", topic);
        ESP_LOGI(TAG, "DATA %s", data);

        if (strcmp(topic, TOPIC_TRAIN_CMD) == 0)
        {
            char L = data[0];

            train_letter(L);
        }
        else if (strcmp(topic, TOPIC_RECOGNIZE) == 0)
        {
            recognize_enabled = 1;

            vote_index = 0;

            ESP_LOGI(TAG, "START RECOGNIZE");
        }

        else if (strcmp(topic, "glove/get_trained") == 0)
        {
            ESP_LOGI(TAG, "REQUEST TRAINED LIST");

            send_trained_letters();
        }
        else if (strcmp(topic, TOPIC_OTA) == 0)
        {
            ESP_LOGI(TAG, "OTA TRIGGERED");

            xTaskCreate(
                ota_task,
                "ota_task",
                8192,
                NULL,
                5,
                NULL);
        }
        else if (strcmp(topic, TOPIC_CLEAR_CMD) == 0)
        {

            if (strstr(data, "ALL") != NULL)
            {
                for (int i = 0; i < 27; i++)
                {
                    memset(&model[i], 0, sizeof(gesture_t));
                }

                save_model();

                ESP_LOGI(TAG, "CLEARED ALL");

                send_trained_letters();
            }

            else
            {
                char L;

                if (data[0] == '"')
                    L = data[1];
                else
                    L = data[0];

                int id = (L == ' ') ? 26 : (L - 'A');

                memset(&model[id], 0, sizeof(gesture_t));

                save_model();

                ESP_LOGI(TAG, "CLEARED %c", L);

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
    uart_config_t uart_config = {
        .baud_rate = 115200,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1};

    uart_param_config(UART_NUM_0, &uart_config);
    uart_driver_install(UART_NUM_0, 256, 0, 0, NULL, 0);

    ESP_ERROR_CHECK(i2c_master_init());
    ESP_ERROR_CHECK(mpu6050_init_sensor());
    adc_oneshot_unit_init_cfg_t uc = {.unit_id = ADC_UNIT_1};
    adc_oneshot_new_unit(&uc, &adc);

    adc_oneshot_chan_cfg_t cfg = {
        .atten = ADC_ATTEN_DB_12,
        .bitwidth = ADC_BITWIDTH_DEFAULT};

    for (int i = 0; i < 5; i++)
        adc_oneshot_config_channel(adc, adc_ch[i], &cfg);

    esp_mqtt_client_config_t m = {
        .broker.address.uri = MQTT_BROKER};

    mqtt_client = esp_mqtt_client_init(&m);

    esp_mqtt_client_register_event(
        mqtt_client,
        ESP_EVENT_ANY_ID,
        mqtt_event_handler,
        NULL);
}

/**************** MAIN ****************/
void app_main(void)
{
    ESP_LOGI(TAG, "SMART GLOVE START");

    wifi_init();

    init_all(); // chứa ADC + MQTT init (chưa start)
    for (int addr = 1; addr < 127; addr++)
    {
        i2c_cmd_handle_t cmd = i2c_cmd_link_create();
        i2c_master_start(cmd);
        i2c_master_write_byte(cmd, (addr << 1) | I2C_MASTER_WRITE, true);
        i2c_master_stop(cmd);

        esp_err_t ret = i2c_master_cmd_begin(I2C_PORT, cmd, 100 / portTICK_PERIOD_MS);
        i2c_cmd_link_delete(cmd);

        if (ret == ESP_OK)
        {
            ESP_LOGI(TAG, "FOUND DEVICE: 0x%X", addr);
        }
    }
    // 🔥 đợi wifi connect
    vTaskDelay(pdMS_TO_TICKS(3000));

    // 🔥 start MQTT sau wifi
    esp_mqtt_client_start(mqtt_client);

    // 🔥 calibrate sau ADC
    calibrate_flex();

    load_model();

    vTaskDelay(pdMS_TO_TICKS(200));
    send_trained_letters();

    ESP_LOGI(TAG, "MODEL LOADED");

    xTaskCreate(
        recognize_task,
        "recognize_task",
        4096,
        NULL,
        5,
        NULL);
}
