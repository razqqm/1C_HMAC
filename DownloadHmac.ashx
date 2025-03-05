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
        // Явно указываем кодировку UTF-8 для ответа
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
            
            // Считываем заголовок X-HMAC-Signature
            string signatureHeader = context.Request.Headers["X-HMAC-Signature"];
            if (string.IsNullOrEmpty(signatureHeader))
            {
                context.Response.StatusCode = 401;
                context.Response.Write("Missing required HMAC header (X-HMAC-Signature).");
                return;
            }
            
            // Получаем имя файла из query-параметра ?file=
            string fileName = context.Request.QueryString["file"];
            if (string.IsNullOrEmpty(fileName))
            {
                context.Response.StatusCode = 400;
                context.Response.Write("No file specified. Use ?file=filename.");
                return;
            }
            
            // Безопасное получение имени файла (убираем возможный путь)
            string safeFileName = Path.GetFileName(fileName);
            
            // Формируем путь к файлу (папка "files" должна находиться в корне сайта)
            string folder = Path.Combine(context.Request.PhysicalApplicationPath, "files");
            string fullPath = Path.Combine(folder, safeFileName);
            if (!File.Exists(fullPath))
            {
                context.Response.StatusCode = 404;
                context.Response.Write("File not found: " + safeFileName);
                return;
            }
            
            // Получаем секрет из web.config
            string secret = ConfigurationManager.AppSettings["HmacSecret"] ?? "CHANGE_ME";
            
            // Формируем каноническую строку – только метод и имя файла:
            // Формат: "GET\n{имя файла}\n"
            string canonicalString = string.Format("GET\n{0}\n", safeFileName);
            
            // Вычисляем HMAC-SHA256
            string computedSignature = CalculateHmacSha256(canonicalString, secret);
            
            // Сравниваем вычисленную подпись с переданной
            if (!ConstantTimeEquals(signatureHeader, computedSignature))
            {
                context.Response.StatusCode = 403;
                context.Response.Write("Signature mismatch.");
                return;
            }
            
            // Отдаем файл
            context.Response.ContentType = "application/octet-stream; charset=utf-8";
            context.Response.AddHeader("Content-Disposition", "attachment; filename=\"" + safeFileName + "\"");
            context.Response.WriteFile(fullPath);
            // Вместо Response.End() вызываем CompleteRequest(), чтобы избежать ThreadAbortException
            context.ApplicationInstance.CompleteRequest();
        }
        catch (Exception ex)
        {
            // Выводим подробное описание ошибки (для отладки)
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
