<%@ WebHandler Language="C#" Class="DownloadHmac" %>
using System;
using System.Web;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Configuration;

public class DownloadHmac : IHttpHandler
{
    public bool IsReusable { get { return false; } }

    public void ProcessRequest(HttpContext context)
    {
        // Указываем кодировку UTF-8 для ответа
        context.Response.ContentEncoding = Encoding.UTF8;
        try
        {
            // Принимаем только GET-запросы
            if (context.Request.HttpMethod != "GET")
            {
                context.Response.StatusCode = 405;
                context.Response.Write("Only GET method is allowed.");
                return;
            }

            //-------------------------------------------
            // 1. Считываем настройки из appSettings
            //-------------------------------------------
            // Путь к папке с файлами
            string folder = ConfigurationManager.AppSettings["FilesFolder"];
            if (string.IsNullOrEmpty(folder))
            {
                // fallback на старое значение
                folder = @"C:\_files_iis\files";
            }

            // Секрет для HMAC
            string secret = ConfigurationManager.AppSettings["HmacSecret"] ?? "CHANGE_ME";

            // Разрешённый IP
            string allowedIP = ConfigurationManager.AppSettings["AllowedIP"];
            // Разрешённый домен
            string allowedDomain = ConfigurationManager.AppSettings["AllowedDomain"];

            //-------------------------------------------
            // 2. Проверка IP (если задан AllowedIP)
            //-------------------------------------------
            if (!string.IsNullOrEmpty(allowedIP))
            {
                string requestIP = context.Request.UserHostAddress;
                if (!requestIP.Equals(allowedIP, StringComparison.OrdinalIgnoreCase))
                {
                    // Но прежде чем вернуть 403, посмотрим — может, у нас ещё домен разрешён
                    // Вдруг AllowedDomain тоже задан, и запрос пришёл с допустимого домена.
                    // Поэтому проверку объединим с доменом чуть ниже.
                }
            }

            //-------------------------------------------
            // 3. Проверка домена (если задан AllowedDomain)
            //-------------------------------------------
            // Берём реферер (UrlReferrer), если нет — значит домен не совпадает.
            bool domainOK = true;  // по умолчанию "true", если домен не задан
            bool ipOK = true;      // по умолчанию "true", если IP не задан

            if (!string.IsNullOrEmpty(allowedIP))
            {
                string requestIP = context.Request.UserHostAddress;
                ipOK = requestIP.Equals(allowedIP, StringComparison.OrdinalIgnoreCase);
            }

            if (!string.IsNullOrEmpty(allowedDomain))
            {
                Uri referrer = context.Request.UrlReferrer;
                if (referrer == null)
                {
                    domainOK = false;
                }
                else
                {
                    domainOK = referrer.Host.Equals(allowedDomain, StringComparison.OrdinalIgnoreCase);
                }
            }

            // Если задан и IP, и домен – нужно, чтобы совпал хотя бы один (логика "ИЛИ").
            // Если задан только IP – тогда ipOK должен быть true.
            // Если задан только домен – тогда domainOK должен быть true.
            if (!ipOK && !domainOK)
            {
                context.Response.StatusCode = 403;
                context.Response.Write("Forbidden by IP/Domain check.");
                return;
            }

            //-------------------------------------------
            // 4. Считываем заголовок X-HMAC-Signature
            //-------------------------------------------
            string signatureHeader = context.Request.Headers["X-HMAC-Signature"];
            if (string.IsNullOrEmpty(signatureHeader))
            {
                context.Response.StatusCode = 401;
                context.Response.Write("Missing required HMAC header (X-HMAC-Signature).");
                return;
            }

            //-------------------------------------------
            // 5. Считываем и проверяем имя файла
            //-------------------------------------------
            string fileName = context.Request.QueryString["file"];
            if (string.IsNullOrEmpty(fileName))
            {
                context.Response.StatusCode = 400;
                context.Response.Write("No file specified. Use ?file=filename.");
                return;
            }

            // Безопасное получение имени файла
            string safeFileName = Path.GetFileName(fileName);
            string fullPath = Path.Combine(folder, safeFileName);

            if (!File.Exists(fullPath))
            {
                context.Response.StatusCode = 404;
                context.Response.Write("File not found: " + safeFileName);
                return;
            }

            //-------------------------------------------
            // 6. Формируем каноническую строку и считаем HMAC
            //-------------------------------------------
            // Формат канонической строки: "GET\n{имя файла}\n"
            string canonicalString = string.Format("GET\n{0}\n", safeFileName);
            string computedSignature = CalculateHmacSha256(canonicalString, secret);

            if (!ConstantTimeEquals(signatureHeader, computedSignature))
            {
                context.Response.StatusCode = 403;
                context.Response.Write("Signature mismatch.");
                return;
            }

            //-------------------------------------------
            // 7. Отдаём файл
            //-------------------------------------------
            context.Response.ContentType = "application/octet-stream; charset=utf-8";
            context.Response.AddHeader("Content-Disposition", "attachment; filename=\"" + safeFileName + "\"");
            context.Response.WriteFile(fullPath);

            // Завершение без ThreadAbortException
            context.ApplicationInstance.CompleteRequest();
        }
        catch (Exception ex)
        {
            // Для отладки – выводим описание ошибки
            context.Response.ContentType = "text/plain; charset=utf-8";
            context.Response.StatusCode = 500;
            context.Response.Write("Server error:\n" + ex.ToString());
        }
    }

    private string CalculateHmacSha256(string message, string secret)
    {
        byte[] keyBytes = Encoding.UTF8.GetBytes(secret);
        byte[] messageBytes = Encoding.UTF8.GetBytes(message);
        using (var hmac = new HMACSHA256(keyBytes))
        {
            byte[] hash = hmac.ComputeHash(messageBytes);
            return BitConverter.ToString(hash).Replace("-", "").ToLower();
        }
    }

    private bool ConstantTimeEquals(string a, string b)
    {
        if (a == null || b == null || a.Length != b.Length)
            return false;
        bool result = true;
        for (int i = 0; i < a.Length; i++)
        {
            result &= (a[i] == b[i]);
        }
        return result;
    }
}
