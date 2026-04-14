idf_component_register(
    SRCS "app_main.c"
    INCLUDE_DIRS "."

    REQUIRES
        esp_adc
        driver
        mpu6050
        
        esp_wifi       # WiFi
        esp_event      # MQTT cần esp_event
        esp_netif      # network interface
        mqtt           # MQTT client
        nvs_flash      # lưu cấu hình WiFi
        esp_https_ota
)
