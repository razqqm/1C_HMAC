# 1C WEB File Server

DownloadHMAC File Server – это ASP.NET‑приложение, реализованное в виде HTTP‑обработчика (ASHX), предназначенное для безопасной выдачи файлов по запросу. Для защиты доступа используется проверка HMAC‑подписи, а также проверка источника запроса по IP-адресу и/или домену. Все ключевые параметры вынесены в конфигурационный файл **web.config**, что позволяет гибко настраивать приложение без перекомпиляции.

## Особенности

- **Безопасная выдача файлов:** Файл отдается только в том случае, если HMAC‑подпись, вычисленная на основе канонической строки и секретного ключа, совпадает с переданной в заголовке `X-HMAC-Signature`.
- **Гибкая конфигурация:** Все параметры (путь к файлам, HMAC‑секрет, разрешенные IP и домен) задаются через `appSettings` в файле **web.config**.
- **Проверка источника запроса:** Возможна проверка как IP-адреса, так и домена (через UrlReferrer). При необходимости можно разрешить запросы, если хотя бы один из параметров совпадает с указанным.
- **Интегрированный режим IIS:** Приложение настроено для работы в Integrated Pipeline.
- **UTF‑8 кодировка:** Все запросы и ответы обрабатываются в кодировке UTF‑8 для корректного отображения символов.
- **Легкая интеграция с Postman:** Пример Pre‑request Script позволяет автоматически вычислять HMAC‑подпись на основе параметра запроса.

## Структура проекта

```
C:\_files_iis\
│
├── web.config           # Файл конфигурации для настройки приложения
├── DownloadHmac.ashx    # ASP.NET обработчик, реализующий логику проверки HMAC и выдачи файлов
└── files\              # Папка с файлами для выдачи (например, test.txt, 0ea50b15-1dfd-af6e-fd14-0e97c00438ff.pdf и т.д.)
```

## Установка и развертывание

1. **Настройка IIS:**
   - Создайте новый сайт в IIS с физическим путем, например, `C:\_files_iis\`.
   - Настройте привязки (bindings) для вашего сайта (HTTP/HTTPS, порт, доменное имя).
   - Убедитесь, что сайт работает в Application Pool с .NET CLR v4.0 (Integrated mode).

2. **Размещение файлов:**
   - Скопируйте файлы **web.config** и **DownloadHmac.ashx** в корневую папку вашего сайта (например, `C:\_files_iis\`).
   - Создайте папку `files` в корне сайта и поместите в неё файлы, которые будут выдаваться (например, `test.txt`, `0ea50b15-1dfd-af6e-fd14-0e97c00438ff.pdf`).

3. **Перезапустите сайт в IIS** (или выполните IISReset).

## Настройка конфигурации (автоматически)

Для автоматической подстановки значений в файл конфигурации мы используем шаблон `web.config.template` и GitHub Actions. Это позволяет заменить плейсхолдеры на реальные значения из переменных окружения (например, GitHub Secrets) во время сборки или развертывания.

### Шаги:

1. **Подготовьте шаблон конфигурации.**  
   В корне репозитория разместите файл `web.config.template` со следующим содержимым:

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <configuration>
     <appSettings>
       <!-- Путь к папке с файлами -->
       <add key="FilesFolder" value="%FILES_FOLDER%" />
       <!-- Секрет для HMAC -->
       <add key="HmacSecret" value="%HMAC_SECRET%" />
       <!-- Разрешённые IP-адреса (несколько, разделяются запятыми) -->
       <add key="AllowedIP" value="%ALLOWED_IP%" />
       <!-- Разрешённый домен (опционально) -->
       <add key="AllowedDomain" value="%ALLOWED_DOMAIN%" />
     </appSettings>
     
     <system.web>
       <compilation debug="true" targetFramework="4.7" />
       <httpRuntime maxRequestLength="2147483647" maxQueryStringLength="2097151" />
       <customErrors mode="Off" />
       <globalization requestEncoding="utf-8" responseEncoding="utf-8" fileEncoding="utf-8" culture="en-US" uiCulture="en-US" />
     </system.web>
     
     <location path="." inheritInChildApplications="false" />
     
     <system.webServer>
       <httpErrors existingResponse="PassThrough" />
       <rewrite>
         <rules>
           <clear />
         </rules>
       </rewrite>
       <handlers>
         <clear />
         <add name="ASHX" 
              path="*.ashx" 
              verb="*" 
              type="System.Web.UI.SimpleHandlerFactory, System.Web, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"
              resourceType="Unspecified"
              preCondition="integratedMode,runtimeVersionv4.0" />
         <add name="PageHandlerFactory-Integrated"
              path="*.aspx"
              verb="*"
              type="System.Web.UI.PageHandlerFactory"
              resourceType="Unspecified"
              requireAccess="Script"
              preCondition="integratedMode,runtimeVersionv4.0" />
       </handlers>
     </system.webServer>
   </configuration>
   ```

2. **Настройте GitHub Secrets.**  
   В настройках репозитория (Settings → Secrets) создайте следующие секреты:
   - `FILES_FOLDER` – например, `C:\_files_iis\files`
   - `HMAC_SECRET` – например, `SUPER_SECRET_123`
   - `ALLOWED_IP` – например, `192.168.1.100,192.168.1.101`
   - `ALLOWED_DOMAIN` – например, `allowed.domain.com` (если используется)

3. **Добавьте GitHub Actions workflow.**  
   Создайте файл `.github/workflows/deploy.yml` со следующим содержимым:

   ```yaml
   name: Deploy Web.Config

   on:
     push:
       branches:
         - main

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Checkout code
           uses: actions/checkout@v3

         - name: Replace placeholders in web.config
           shell: bash
           env:
             FILES_FOLDER: ${{ secrets.FILES_FOLDER }}
             HMAC_SECRET: ${{ secrets.HMAC_SECRET }}
             ALLOWED_IP: ${{ secrets.ALLOWED_IP }}
             ALLOWED_DOMAIN: ${{ secrets.ALLOWED_DOMAIN }}
           run: |
             echo "Replacing placeholders in web.config.template..."
             if [ ! -f web.config.template ]; then
               echo "File web.config.template not found in the repository root!"
               exit 1
             fi
             sed -e "s|%FILES_FOLDER%|${FILES_FOLDER}|g" \
                 -e "s|%HMAC_SECRET%|${HMAC_SECRET}|g" \
                 -e "s|%ALLOWED_IP%|${ALLOWED_IP}|g" \
                 -e "s|%ALLOWED_DOMAIN%|${ALLOWED_DOMAIN}|g" \
                 web.config.template > web.config
             cat web.config
   ```

   Этот workflow запускается при пуше в ветку `main`, заменяет все плейсхолдеры в файле `web.config.template` на значения из GitHub Secrets и сохраняет итоговый файл как `web.config`.

## Конфигурация (вручную)

Если вы предпочитаете настроить конфигурацию вручную, выполните следующие шаги:

1. Переименуйте файл `web.config.template` в `web.config`.
2. Откройте файл `web.config` в текстовом редакторе и замените следующие плейсхолдеры на реальные значения:
   - **%FILES_FOLDER%** – путь к папке с файлами (например, `C:\_files_iis\files`)
   - **%HMAC_SECRET%** – секрет для HMAC (например, `SUPER_SECRET_123`)
   - **%ALLOWED_IP%** – список разрешённых IP (например, `192.168.1.100,192.168.1.101`)
   - **%ALLOWED_DOMAIN%** – разрешённый домен (если используется, например, `allowed.domain.com`)
3. Сохраните файл.

Дополнительные настройки в секциях `<system.web>` и `<system.webServer>` уже настроены для компиляции, кодировки и обработки ошибок.

## Итог

- **Автоматическая конфигурация:** Используйте GitHub Actions для автоматической замены плейсхолдеров в `web.config.template` с помощью переменных окружения, заданных в GitHub Secrets.
- **Ручная конфигурация:** Переименуйте файл `web.config.template` в `web.config` и вручную замените плейсхолдеры на реальные значения.

Дополнительно в секциях `<system.web>` и `<system.webServer>` задаются параметры компиляции, кодировки и обработки ошибок.

## Как работает обработчик

1. **Проверка метода запроса:**  
   Обработчик принимает только GET‑запросы.

2. **Проверка источника запроса:**  
   Если в конфигурации заданы `AllowedIP` и/или `AllowedDomain`, обработчик проверяет, совпадает ли IP‑адрес клиента (`UserHostAddress`) или домен (поле Host у `UrlReferrer`) с разрешёнными значениями. Если ни один из параметров не совпадает, запрос отклоняется (HTTP 403).

3. **Проверка HMAC‑подписи:**  
   Обработчик ожидает заголовок `X-HMAC-Signature`. Он формирует каноническую строку в виде:
   ```
   GET
   {имя файла}
   ```
   и вычисляет HMAC‑SHA256, используя секрет из конфигурации. Если вычисленная подпись не совпадает с переданной, запрос отклоняется (HTTP 403).

4. **Выдача файла:**  
   При успешном прохождении всех проверок файл из указанной папки отдается клиенту с соответствующими HTTP‑заголовками для скачивания.

## Использование с Postman

### Настройка запроса

1. **Метод и URL:**  
   - Метод: GET  
   - URL:  
     ```
     https://files1c.cocrealty.biz/DownloadHmac.ashx?file={{fileName}}
     ```
     где переменная `fileName` содержит имя запрашиваемого файла, например, `0ea50b15-1dfd-af6e-fd14-0e97c00438ff.pdf`.

2. **Pre-request Script:**  
   Используйте следующий скрипт, который автоматически извлекает параметр `file` из URL, вычисляет каноническую строку и HMAC‑подпись, и сохраняет её в переменную окружения `HMACSignature`:

   ```javascript
   // Секрет – должен совпадать с настройками сервера
   var secret = "SUPER_SECRET_123";
   
   // Извлекаем значение параметра "file" из URL
   var fileParam = _.find(pm.request.url.query.all(), function(q) {
       return q.key === "file";
   });
   var fileName = fileParam ? fileParam.value : "test.txt";
   
   // Формируем каноническую строку: "GET\n{fileName}\n"
   var canonicalString = "GET\n" + fileName + "\n";
   
   // Вычисляем HMAC-SHA256 с использованием CryptoJS
   var signature = CryptoJS.HmacSHA256(canonicalString, secret).toString(CryptoJS.enc.Hex);
   
   // Сохраняем вычисленное значение в переменную окружения "HMACSignature"
   pm.environment.set("HMACSignature", signature);
   
   console.log("Canonical String: " + canonicalString);
   console.log("Computed Signature: " + signature);
   ```

3. **Заголовки:**  
   Добавьте заголовок:
   - **Key:** `X-HMAC-Signature`
   - **Value:** `{{HMACSignature}}`

4. **Отправка запроса:**  
   После настройки отправьте запрос. Если вычисленная подпись совпадает с ожидаемой, сервер вернет файл.

## Дополнительные параметры

Помимо перечисленных ключей, вы можете вынести в конфигурацию:
- **Параметры логирования:** для более детального отслеживания запросов.
- **Параметры Content-Type:** если требуется выдавать файлы с другим MIME‑типом.
- **Параметры кеширования:** для управления кешированием файлов.

## Заключение

DownloadHMAC File Server демонстрирует, как с помощью ASP.NET‑обработчика можно реализовать безопасную выдачу файлов с использованием HMAC‑подписи и проверки источника запроса по IP и домену. Все ключевые настройки вынесены в файл web.config, что упрощает адаптацию и развертывание приложения в различных средах.

Если у вас возникнут вопросы или предложения, пожалуйста, создайте Issue или отправьте Pull Request.
