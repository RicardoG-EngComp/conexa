# Checklist Manual — aparelho físico

> Documento para você e o testador seguirem antes de liberar cada versão do Conexa.
> Preencher ✅/❌ e anexar evidência (screenshot/print) para cada item.

## Pré-requisitos

- [ ] App instalado via App Tester (última versão)
- [ ] Notificações permitidas
- [ ] Duas contas de teste disponíveis (Account A e Account B)
- [ ] Wi-Fi ou dados móveis ativos

---

## 1. Instalação via App Tester

**O que validar:** o app instala e abre sem travar após atualização ou instalação limpa.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| App abre após instalação via App Tester | | | |
| Tutorial aparece 1x na primeira instalação | | | |
| Atualização do beta preserva login e dados | | | |

**Passos:**
1. Abra o App Tester no celular.
2. Baixe a versão mais recente do Conexa.
3. Aguarde a instalação terminar.
4. Abra o app e confirme que não trava.
5. Se for primeira instalação, verifique que o tutorial aparece.

---

## 2. Push real nas 4 categorias

**O que validar:** push chega e abre a rota correta para cada tipo de notificação.

### 2.1 Pedido de mensagem

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Push "Novo pedido de mensagem" chega | | | |
| Toque abre aba Pedidos | | | |
| Item aparece na central com badge | | | |

**Passos:**
1. Deixe o Account A com o app aberto ou fechado.
2. Da conta B, envie um pedido de mensagem para A.
3. Aguarde o push no aparelho A.
4. Toque no push e confirme que abre a aba Pedidos.

### 2.2 Conexão aceita

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Push "Conexão aceita" chega | | | |
| Toque abre aba Conexões | | | |

**Passos:**
1. Da conta B, aceite o pedido de conexão pendente de A.
2. Aguarde o push no aparelho A.
3. Toque no push e confirme que abre a aba Conexões.

### 2.3 Nova mensagem

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Push "Nova mensagem" chega | | | |
| Push não mostra remetente nem conteúdo | | | |
| Toque abre a conversa correta | | | |

**Passos:**
1. Em uma conversa aceita, a conta B envia uma mensagem para A.
2. Aguarde o push no aparelho A.
3. Verifique que o push mostra apenas "Nova mensagem".
4. Toque no push e confirme que abre a conversa correta.

### 2.4 Estudos

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Admin recebe "Novo material pendente" | | | |
| Autor recebe "Material aprovado" | | | |
| Autor recebe "Material rejeitado" | | | |

**Passos:**
1. O autor (pode ser A ou B) envia um material de estudo.
2. O admin recebe o push "Novo material pendente" no seu aparelho.
3. O admin aprova ou rejeita o material.
4. O autor recebe o push "Material aprovado" ou "Material rejeitado".

---

## 3. Permissão negada

**O que validar:** o app continua funcionando sem push; central e badges não quebram.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| App abre normalmente sem permissão | | | |
| Central e badges funcionam | | | |
| Nenhuma notificação do sistema aparece | | | |
| Opção "Ativar" em Ajustes funciona | | | |

**Passos:**
1. Vá em Ajustes do Android → Apps → Conexa → Notificações.
2. Revogue a permissão.
3. Abra o app e use as principais telas.
4. Verifique que a central mostra eventos e o badge funciona.
5. Ative novamente pela opção em Ajustes > Notificações.

---

## 4. Bloqueado / recusado não notifica

**O que validar:** nenhuma notificação é gerada para bloqueados ou recusados.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Bloqueio impede pedido e push | | | |
| Recusa impede pedido e push | | | |

**Passos:**
1. Da conta A, bloqueie a conta B.
2. Da conta B, tente enviar pedido de mensagem ou conexão para A.
3. Confirme que A não recebe nenhum push.
4. Desbloqueie.

---

## 5. Preferência desligada

**O que validar:** categoria desativada não gera push nem item na central.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Categoria "Mensagens" desligada não gera push | | | |
| Categoria "Conexões" desligada não gera push | | | |
| Categoria "Estudos" desligada não gera push | | | |
| Categoria "Pedidos" desligada não gera push | | | |
| Ao religar, o push volta a funcionar | | | |

**Passos:**
1. Acesse Ajustes > Notificações.
2. Desligue a categoria "Mensagens".
3. Da outra conta, envie uma mensagem.
4. Confirme que o push não chega e que a central não mostra o item.
5. Religue a categoria e repita para confirmar que volta.

---

## 6. Logout e login com outra conta

**O que validar:** nenhum push da conta anterior é recebido após logout.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Logout remove notificações locais | | | |
| Nenhuma notificação da conta anterior chega | | | |
| Nova conta recebe apenas as próprias notificações | | | |

**Passos:**
1. Na conta A, anote quais notificações estão na central.
2. Vá em Ajustes > Sair da conta.
3. Entre com a conta B no mesmo aparelho.
4. Verifique que nenhuma notificação da conta A aparece.
5. Envie uma notificação para B e confirme que chega no aparelho.

---

## 7. Fonte grande e tela pequena

**O que validar:** layout íntegro com configurações de acessibilidade.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Feed sem overflow com fonte grande | | | |
| Descobrir sem overflow | | | |
| Conversas sem overflow | | | |
| Notificações sem overflow | | | |
| Ajustes sem overflow | | | |
| Tutorial sem overflow | | | |

**Passos:**
1. Vá em Ajustes do Android → Display → Tamanho da fonte.
2. Aumente para o máximo.
3. Abra o Conexa e navegue por todas as telas.
4. Verifique que nenhum texto está cortado, sobreposto ou fora da tela.
5. Reduza a fonte para o normal.

---

## 8. Doze / economia de bateria

**O que validar:** push pode atrasar mas a central registra ao abrir.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Push pode atrasar mas não se perde | | | |
| Central registra o evento ao abrir o app | | | |
| Badge mostra não lidas após abrir | | | |

**Passos:**
1. Ative economia de bateria no Android para o app Conexa.
2. Com o app fechado, peça para a outra conta enviar uma mensagem.
3. Aguarde até 5 minutos pelo push.
4. Se o push não chegar nesse tempo, abra o app.
5. Confirme que a central mostra o item com badge de não lidas.

---

## 9. App force-stopped

**O que validar:** ao reabrir após force-stop, a central busca o que faltou.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Push pode não chegar no force-stop | | | |
| Ao reabrir, central busca o que faltou | | | |
| Não há duplicidade de notificações | | | |

**Passos:**
1. Vá em Ajustes do Android → Apps → Conexa → Forçar parada.
2. A outra conta envia uma mensagem.
3. Aguarde 1 minuto — o push pode não chegar.
4. Abra o app normalmente.
5. Confirme que a central mostra a mensagem com badge.

---

## 10. Instalação limpa (desinstalar + reinstalar)

**O que validar:** tutorial aparece 1x, notificações chegam após permissão, sem dados órfãos.

| Item | ✅/❌ | Comentário | Evidência |
|---|---|---|---|
| Desinstalar remove app e dados locais | | | |
| Reinstalar via App Tester funciona | | | |
| Tutorial aparece 1x | | | |
| Token registrado após login | | | |
| Push chega após permissão | | | |

**Passos:**
1. Desinstale o app do aparelho.
2. Reinstale via App Tester.
3. Abra o app — o tutorial deve aparecer.
4. Conclua ou pule o tutorial.
5. Permita notificações.
6. Entre com a conta de teste.
7. Peça para a outra conta enviar uma mensagem.
8. Confirme que o push chega e abre a conversa.

---

## Resumo da rodada

| Cenário | ✅/❌ | Testador | Data | Versão |
|---|---|---|---|---|
| 1. Instalação via App Tester | | | | |
| 2. Push nas 4 categorias | | | | |
| 3. Permissão negada | | | | |
| 4. Bloqueado/recusado | | | | |
| 5. Preferência desligada | | | | |
| 6. Logout/troca de conta | | | | |
| 7. Fonte grande | | | | |
| 8. Doze/bateria | | | | |
| 9. App force-stopped | | | | |
| 10. Instalação limpa | | | | |

**Versão testada:** _______________
**Data da rodada:** _______________
**Testador(es):** _______________
