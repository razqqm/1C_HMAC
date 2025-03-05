// Задаем секрет. Убедитесь, что он совпадает с тем, что указан в web.config (HmacSecret)
var secret = "SUPER_SECRET_123";

// Извлекаем параметр "file" из URL запроса.
// Используем lodash, которая встроена в Postman.
var fileParam = _.find(pm.request.url.query.all(), function(q) {
    return q.key === "file";
});
var fileName = fileParam ? fileParam.value : "test.txt"; // если параметр не найден, используется "test.txt"

// Формируем каноническую строку: "GET\n{имя файла}\n"
// Обязательно с переводом строки в конце.
var canonicalString = "GET\n" + fileName + "\n";

// Вычисляем HMAC-SHA256 с использованием CryptoJS (встроена в Postman)
var signature = CryptoJS.HmacSHA256(canonicalString, secret).toString(CryptoJS.enc.Hex);

// Сохраняем вычисленное значение в переменную окружения "HMACSignature"
pm.environment.set("HMACSignature", signature);

// Выводим в консоль для отладки
console.log("Canonical String: " + canonicalString);
console.log("Computed Signature: " + signature);
