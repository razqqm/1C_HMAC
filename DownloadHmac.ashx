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
        // Устанавливаем кодировку UTF-8 для ответа
        context.Response.ContentEncoding = Encoding.UTF8;
        try
        {
            // 1. Проверка метода запроса (только GET)
            if (context.Request.HttpMethod != "GET")
            {
                context.Response.StatusCode = 405;
                context.Response.Write("Only GET method is allowed.");
                return;
            }
            
            // 2. Чтение настроек из appSettings
            // Путь к файлам (если не задан, используется значение по умолчанию)
            string folder = ConfigurationManager.AppSettings["FilesFolder"];
            if (string.IsNullOrEmpty(folder))
            {
                folder = @"C:\_files_iis\files";
            }
            
            // Секрет для HMAC
            string secret = ConfigurationManager.AppSettings["HmacSecret"] ?? "CHANGE_ME";
            
            // Разрешённые IP (несколько IP через запятую)
            string allowedIPString = ConfigurationManager.AppSettings["AllowedIP"];
            // Разрешённый домен
            string allowedDomain = ConfigurationManager.AppSettings["AllowedDomain"];
            
            // 3. Проверка IP и домена
            bool ipAllowed = true;
            if (!string.IsNullOrEmpty(allowedIPString))
            {
                string requestIP = context.Request.UserHostAddress;
                string[] allowedIPs = allowedIPString.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                ipAllowed = false;
                foreach (string ip in allowedIPs)
                {
                    if (requestIP.Trim().Equals(ip.Trim(), StringComparison.OrdinalIgnoreCase))
                    {
                        ipAllowed = true;
                        break;
                    }
                }
            }
            
            bool domainAllowed = true;
            if (!string.IsNullOrEmpty(allowedDomain))
            {
                Uri referrer = context.Request.UrlReferrer;
                if (referrer == null)
                {
                    domainAllowed = false;
                }
                else
                {
                    domainAllowed = referrer.Host.Equals(allowedDomain, StringComparison.OrdinalIgnoreCase);
                }
            }
            
            // Если ни IP, ни домен не разрешены, отклоняем запрос
            if (!ipAllowed && !domainAllowed)
            {
                context.Response.StatusCode = 403;
                context.Response.Write("Forbidden by IP/Domain check.");
                return;
            }
            
            // 4. Считывание заголовка X-HMAC-Signature
            string signatureHeader = context.Request.Headers["X-HMAC-Signature"];
            if (string.IsNullOrEmpty(signatureHeader))
            {
                context.Response.StatusCode = 401;
                context.Response.Write("Missing required HMAC header (X-HMAC-Signature).");
                return;
            }
            
            // 5. Считывание и проверка имени файла из query-параметра ?file=
            string fileName = context.Request.QueryString["file"];
            if (string.IsNullOrEmpty(fileName))
            {
                context.Response.StatusCode = 400;
                context.Response.Write("No file specified. Use ?file=filename.");
                return;
            }
            
            // Безопасное получение имени файла (убираем возможный путь)
            string safeFileName = Path.GetFileName(fileName);
            string fullPath = Path.Combine(folder, safeFileName);
            if (!File.Exists(fullPath))
            {
                context.Response.StatusCode = 404;
                context.Response.Write("File not found: " + safeFileName);
                return;
            }
            
            // 6. Формирование канонической строки и вычисление HMAC
            // Формат: "GET\n{имя файла}\n" (обязательно с переводом строки в конце)
            string canonicalString = string.Format("GET\n{0}\n", safeFileName);
            string computedSignature = CalculateHmacSha256(canonicalString, secret);
            
            // Если подписи не совпадают, возвращаем ошибку с отладочной информацией
            if (!ConstantTimeEquals(signatureHeader, computedSignature))
            {
                context.Response.StatusCode = 403;
                context.Response.Write("Signature mismatch.\n");
                context.Response.Write("Canonical String: " + canonicalString + "\n");
                context.Response.Write("Computed Signature: " + computedSignature + "\n");
                context.Response.Write("Provided Signature: " + signatureHeader + "\n");
                return;
            }
            
            // 7. Отдача файла
            context.Response.ContentType = "application/octet-stream; charset=utf-8";
            context.Response.AddHeader("Content-Disposition", "attachment; filename=\"" + safeFileName + "\"");
            context.Response.WriteFile(fullPath);
            context.ApplicationInstance.CompleteRequest();
        }
        catch (Exception ex)
        {
            // Вывод подробного описания ошибки (отладка)
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
