# Backend do formulário beta (Apps Script)

1. Abra a planilha **Conexa — Respostas Beta 2026**:
   `https://docs.google.com/spreadsheets/d/1QyZtZA7oQxoRrCEtQ8M378Edfa5vRwjKzuO1dYh0jMs/edit`
2. Menu **Extensões → Apps Script**.
3. Apague o conteúdo e cole o código de `Code.gs`.
4. Salve e execute `doPost` uma vez para autorizar.
5. **Implantar → Nova implantação → Tipo: Aplicativo da Web**.
6. Executar como: **Eu**.
7. Quem tem acesso: **Qualquer pessoa**.
8. Copie a URL que termina em `/exec`.
9. Cole a URL em `docs/beta-config.js`:

```js
window.CONEXA_BETA_ENDPOINT = "https://script.google.com/macros/s/.../exec";
```

10. Faça commit/push e teste a página:
    `https://ricardog-engcomp.github.io/conexa/beta.html`

A planilha ganhará uma aba **Site** com as inscrições. A página usa um POST nativo com iframe, então não depende de CORS. Os dados não passam pela URL.
