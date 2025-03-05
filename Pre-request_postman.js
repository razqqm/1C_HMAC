// Получаем секрет из переменной или задаем напрямую
var secret = "SUPER_SECRET_123";

// Получаем имя файла из переменной окружения "fileName"; если переменная не задана, используем значение "test.txt"
var fileName = pm.environment.get("fileName") || "test.txt";

// Формируем каноническую строку в формате:
// "GET\n{имя файла}\n"
// Обязательно с переводом строки в конце.
var canonicalString = "GET\n" + fileName + "\n";

// Вычисляем HMAC-SHA256 с использованием CryptoJS (библиотека встроена в Postman)
var signature = CryptoJS.HmacSHA256(canonicalString, secret).toString(CryptoJS.enc.Hex);

// Сохраняем вычисленное значение в переменную окружения "HMACSignature"
pm.environment.set("HMACSignature", signature);

// Для отладки выводим каноническую строку и вычисленную подпись в консоль
console.log("Canonical String: " + canonicalString);
console.log("Computed Signature: " + signature);
