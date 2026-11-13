# Mapa de Telas

## Estrutura de navegação
```
App
├── Onboarding (sem login)
│   ├── Boas-vindas / 18+
│   ├── Criar conta
│   ├── Consentimentos
│   ├── Verificação de identidade
│   ├── Montar perfil
│   ├── Preferências
│   └── Tutorial (1x) / Notificações
└── Principal (logado)
    ├── Feed
    │   ├── Abas: Para Você / Conexão
    │   ├── FAB → Publicar / Publicar em grupo / Criar grupo
    │   ├── Publicação (visibilidade, tópicos, cargo, citação)
    │   └── Detalhe do post (respostas de até 3 níveis, citação, moderação)
    ├── Descobrir
    │   ├── Pessoas
    │   ├── Grupos (diretório público + perfil de grupo)
    │   └── Estudos
    ├── Conversas
    │   └── Chat
    ├── Perfil de grupo (membros, cargos, seguidores, convites)
    ├── Criar / Gerenciar grupo
    └── Configurações
```
```
Admin (web)
├── Fila de moderação
├── Aprovar grupos públicos (selo oficial)
├── Gestão de usuários
├── Estudos pendentes
└── Denúncias
```

## Fluxo principal (onboarding)
```
[18+] -> [Conta] -> [Consentimentos] -> [Documento] -> [Selfie] -> [Resultado]
   |                                                                  |
   +------------------------- (falha) -> [Revisão] <------------------+
                                                                      |
[Perfil] <- [Estilo de relação] <- [Interesses] <- [Prompts] <- [Fotos]
   |
[Preferências] -> [Localização] -> [Descobrir]
```

---

## Wireframes (baixa fidelidade)

### 1. Boas-vindas / 18+
```
+----------------------------------+
|                                  |
|         [ marca / nome ]         |
|                                  |
|   Um espaço para conexões reais  |
|                                  |
|   Este app é para maiores de 18  |
|                                  |
|   [ Tenho 18 anos ou mais ]      |
|   [ Sair ]                       |
+----------------------------------+
```

### 2. Criar conta
```
+----------------------------------+
|  <                               |
|  Criar conta                     |
|                                  |
|  E-mail                          |
|  [__________________________]    |
|                                  |
|  Senha                           |
|  [__________________________]    |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 3. Consentimentos
```
+----------------------------------+
|  <  Privacidade e consentimento  |
|                                  |
|  [x] Termos de Uso               |
|  [x] Política de Privacidade     |
|  [ ] Uso de biometria (selfie)   |
|      (obrigatório p/ verificar)  |
|  [ ] Localização aproximada      |
|                                  |
|  [ Aceitar e continuar ]         |
+----------------------------------+
```

### 4. Verificação — documento
```
+----------------------------------+
|  <  Verificação (1/3)            |
|                                  |
|  Frente da CIN/CNH               |
|  +----------------------------+  |
|  |      [ câmera ]            |  |
|  |   enquadre o documento     |  |
|  +----------------------------+  |
|                                  |
|  Verso com QR Code               |
|  +----------------------------+  |
|  |      [ câmera ]            |  |
|  +----------------------------+  |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 5. Verificação — selfie/liveness
```
+----------------------------------+
|  <  Verificação (2/3)            |
|                                  |
|        +------------+            |
|        |   ( rosto )|            |
|        |            |            |
|        +------------+            |
|                                  |
|  Olhe para a câmera e pisque     |
|                                  |
|  [ Iniciar prova de vida ]       |
+----------------------------------+
```

### 6. Resultado
```
+----------------------------------+
|  Verificação (3/3)               |
|                                  |
|            ( ok )                |
|                                  |
|  Identidade confirmada           |
|  Você tem 18 anos ou mais        |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 7. Perfil — fotos
```
+----------------------------------+
|  <  Seu perfil (1/4)             |
|                                  |
|  Adicione fotos                  |
|  +--------+ +--------+           |
|  | foto 1 | | foto 2 |           |
|  +--------+ +--------+           |
|  +--------+ +--------+           |
|  | +      | | +      |           |
|  +--------+ +--------+           |
|                                  |
|  Dica: luz natural e rosto       |
|  visível funcionam melhor        |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 8. Perfil — prompts
```
+----------------------------------+
|  <  Seu perfil (2/4)             |
|                                  |
|  Responda 3 prompts              |
|                                  |
|  "Um domingo perfeito é..."      |
|  [__________________________]    |
|                                  |
|  "Procuro alguém que..."         |
|  [__________________________]    |
|                                  |
|  "Meu maior talento é..."        |
|  [__________________________]    |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 9. Perfil — estilo de relação
```
+----------------------------------+
|  <  Seu perfil (3/4)             |
|                                  |
|  Como você se relaciona?         |
|  ( ) Monogamia                   |
|  ( ) Não-monogamia               |
|  ( ) Casal / trisal              |
|  ( ) Prefiro não dizer           |
|                                  |
|  [ ] Estou em um relacionamento  |
|      -> Vincular parceiro        |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 10. Preferências
```
+----------------------------------+
|  <  Preferências                 |
|                                  |
|  Quero ver                       |
|  [ Gênero v ] [ Idade v ]        |
|  [ Distância v ] [ Intenção v ]  |
|                                  |
|  [ Começar a usar ]              |
+----------------------------------+
```

### 11. Descobrir (feed)
```
+----------------------------------+
|  Descobrir              [filtros]|
|                                  |
|  +----------------------------+  |
|  |        [ foto ]            |  |
|  |                            |  |
|  |  Ana, 24                  |  |
|  |  "Um domingo perfeito é..."|  |
|  +----------------------------+  |
|                                  |
|  [ X ]        [ ♥ ]     [ -> ]   |
|                                  |
|  (próximo perfil...)             |
+----------------------------------+
```

### 12. Detalhe do perfil
```
+----------------------------------+
|  <                        [ ... ]|
|  +----------------------------+  |
|  |        [ foto ]            |  |
|  +----------------------------+  |
|  Ana, 24                         |
|  Relaciona-se com @bia          |
|                                  |
|  Prompt 1 ...                    |
|  Prompt 2 ...                    |
|                                  |
|  [ ♥ Curtir ]   [ Enviar msg ]  |
+----------------------------------+
```

### 13. Curtidas / Conexões
```
+----------------------------------+
|  Curtidas                        |
|  [ Quem curtiu você ]            |
|  +------+ +------+ +------+      |
|  | foto | | foto | | foto |      |
|  +------+ +------+ +------+      |
|                                  |
|  Conexões                        |
|  +------+ +------+               |
|  | foto | | foto |               |
|  +------+ +------+               |
+----------------------------------+
```

### 14. Lista de conversas
```
+----------------------------------+
|  Conversas                       |
|  +------+ Ana           12:40   |
|  | foto | última msg...         |
|  +------+                        |
|  +------+ Bia           10:12   |
|  | foto | última msg...         |
|  +------+                        |
+----------------------------------+
```

### 15. Chat
```
+----------------------------------+
|  <  Ana                   [ ... ]|
|                                  |
|         [ oi! tudo bem? ]        |
|  [ e aí, o que você curte? ]     |
|                                  |
|  +----------------------------+  |
|  | [ aviso de segurança ]     |  |
|  | "Mensagem pode ser invasiva"| |
|  +----------------------------+  |
|                                  |
|  [ Coach ] [___________] [ -> ]  |
+----------------------------------+
```

### 16. AI Coach (assinante)
```
+----------------------------------+
|  <  Coach                        |
|                                  |
|  [ Dicas de foto ]               |
|  [ Sugerir abertura ]            |
|  [ Analisar meu perfil ]         |
|                                  |
|  Sugestão para Ana:              |
|  "Você também curte trilhas?    |
|   Qual foi a última que fez?"    |
|                                  |
|  [ Copiar ]  [ Usar ]            |
+----------------------------------+
```

### 17. Assinatura
```
+----------------------------------+
|  <  Assinatura                   |
|                                  |
|  Grátis: filtros básicos         |
|  Assinante: filtros + Coach      |
|                                  |
|  ( ) R$ 10/mês                   |
|  ( ) R$ 5/mês (indicação)        |
|  ( ) Anual (desconto)            |
|                                  |
|  [ Assinar com Pix ]             |
+----------------------------------+
```

### 18. Configurações
```
+----------------------------------+
|  <  Configurações                |
|  Privacidade e consentimentos    |
|  Localização                     |
|  Segurança                       |
|  Bloquear usuários               |
|  Excluir conta                   |
+----------------------------------+
```

### 19. Denúncia / Bloqueio
```
+----------------------------------+
|  <  Denunciar                    |
|                                  |
|  Motivo:                         |
|  ( ) Assédio                     |
|  ( ) Perfil falso                |
|  ( ) Imagem sem consentimento    |
|  ( ) Menor de idade              |
|  ( ) Outro                       |
|                                  |
|  [ Enviar denúncia ]             |
|  [ Bloquear usuário ]            |
+----------------------------------+
```

---

## 1.0.14 — Feed e Grupos

### F.1 Feed (abas + FAB)
```
+----------------------------------+
| Feed UFV                   [sino]|
| [ Para você | Conexão ]          |
| +----------------------------+  |
| | Ana · C. da Computação     |  |
| | "roda de conversa..."      |  |
| | [Diretoria · CAC] (cargo)  |  |
| | [curso][campus][evento]    |  |
| | ( 48 curtidas, 6 respostas )| |
| | Republicar                 |  |
| +----------------------------+  |
|                        ( FAB + ) |
+----------------------------------+
FAB -> Publicar / Publicar em grupo / Criar grupo
```

### F.2 Página de publicação
```
+----------------------------------+
| <  Publicar                      |
| [ texto: o que compartilhar? ]   |
| Quem pode ver: (Público|Conexões)|
| Tópicos: curso / campus /        |
|          categorias (até 3)      |
| Selo de cargo (grupos verif.)    |
| Em grupo: cargo + "em nome"      |
| [ Publicar ]                     |
+----------------------------------+
```

### F.3 Perfil de grupo
```
+----------------------------------+
| <  Grupo                  [...]  |
| [avatar] Centro Acad. Comp.      |
| [Grupo oficial][cat][campus]     |
| Membros 12 . Seguidores 340      |
| [ Entrar/Sair ] [ Seguir ]       |
| [Membros][Cargos][Seguidores]    |
| [Convites]                       |
+----------------------------------+
Convites: criar (validade/usos) ->
copiar link 1x -> status -> revogar
```

### F.4 Aprovação de grupo (admin)
```
+----------------------------------+
| <  Aprovar grupos                |
| +----------------------------+  |
| | Grupo X · cat · campus     |  |
| | descrição...               |  |
| | [ Rejeitar ] [ Aprovar ]   |  |
| +----------------------------+  |
+----------------------------------+
```

---

## 1.0.15 - Feedback

Rotas: `/feedback`, `/feedback/bug`, `/feedback/suggestion` e `/admin/feedback`.
Entradas: Ajuda, Ajustes e ícone na Administração.

### FB.1 Feedback (home)
```
+----------------------------------+
| <  Feedback                      |
| Ajude a melhorar o Conexa        |
| [ Reportar um problema      > ]  |
| [ Enviar uma sugestão       > ]  |
|                                  |
| Meus envios                      |
| BUG-000123  [Recebido]           |
| Enviado agora                    |
+----------------------------------+
```

### FB.2 Reportar problema
```
+----------------------------------+
| <  Reportar problema             |
| Título                           |
| O que aconteceu?                 |
| > Detalhes opcionais             |
|   Passos / esperado / acontecido |
|   Aparelho e sistema             |
| [ Anexar print (opcional) ]      |
| [ Enviar relato ]                |
+----------------------------------+
```

### FB.3 Enviar sugestão
```
+----------------------------------+
| <  Enviar sugestão               |
| Título                           |
| Descreva a sugestão              |
| > Detalhes opcionais             |
|   Problema / proposta / impacto  |
| [ Enviar sugestão ]              |
+----------------------------------+
```

### FB.4 Feedback no admin
```
+----------------------------------+
| <  Feedback                      |
| [ Bugs ] [ Sugestões ]           |
| (Abertos)(Em andamento)(Encerr.) |
| +----------------------------+   |
| | Título                     |   |
| | BUG-000123 · status · tempo|   |
| +----------------------------+   |
| toque -> detalhe + print +       |
|          mudança de status       |
+----------------------------------+
```

---

## Ordem de construção das telas
1. **B1:** 1–6 (18+, conta, consentimento, verificação).
2. **B2:** 7–10 + 18 (perfil, estilo de relação, preferências, configurações).
3. **B3:** 11–13 (descobrir, detalhe, curtidas).
4. **B4:** 14–15 + 19 (conversas, chat, denúncia).
5. **B5:** 16 (Coach).
6. **B6:** mapa/perto de você.
7. **B7:** 17 (assinatura).
8. **B8/B9:** admin web.
