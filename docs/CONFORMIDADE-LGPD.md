# Checklist de conformidade — LGPD, ECA Digital e CDC

> ⚠️ Documento de planejamento. **Não é aconselhamento jurídico.**
> Revisão por advogado especializado é recomendada antes do lançamento.

## Por que este app é de alto risco
- Trata **dados sensíveis**: vida sexual e **biometria** (Art. 5º, II, LGPD).
- Trata **localização**, que pode revelar rotina, religião, saúde.
- Permite **conteúdo adulto**, com risco de material ilegal e não consentido.
- Envolve **menores** (deve ser impedido) e **pagamentos**.

## 1. Governança
- [ ] CNPJ (LTDA) para separar patrimônio pessoal.
- [ ] Encarregado (DPO) nomeado e contato publicado.
- [ ] ROPA (registro das operações de tratamento).
- [ ] DPIA/RIPD (dados sensíveis + localização + IA + conteúdo adulto).
- [ ] LIA (legítimo interesse para antifraude/segurança).

## 2. Bases legais e consentimento
- [ ] Base legal definida por finalidade.
- [ ] Consentimento **específico e destacado** para biometria e vida sexual.
- [ ] Consentimentos granulares e versionados.
- [ ] Registro de aceite (data, versão, IP).
- [ ] Base legal do canal de feedback (legítimo interesse) registrada na ROPA.

## 3. Direitos do titular
- [ ] Acesso, correção, exclusão, portabilidade e revogação no app.
- [ ] Feedback e prints do titular incluídos na exclusão de conta.
- [ ] Prazo e fluxo de resposta documentados.

## 4. Segurança
- [ ] TLS + criptografia em repouso.
- [ ] Pseudonimização de identificadores.
- [ ] Controle de acesso e logs de auditoria.
- [ ] Prints de feedback em bucket privado (dono/admin), com limite de tamanho e tipo.
- [ ] Teste de segurança antes do lançamento.

## 5. Terceiros / operadores
- [ ] Contratos (DPA) com cloud, PSP, e-mail/SMS, moderação, backup.
- [ ] Verificação de transferência internacional.
- [ ] Nenhum compartilhamento com adtech.

## 6. Idade (18+)
- [ ] Verificação por documento + liveness (ver `FLUXO-VERIFICACAO.md`).
- [ ] Política 18+ e fluxo de denúncia de menor.
- [ ] Re-verificação periódica e por sinais de fraude.
- [ ] Mecanismos compatíveis com o ECA Digital.

## 7. Conteúdo
- [ ] Diretrizes da Comunidade.
- [ ] Proibição de exploração, serviços sexuais pagos e assédio.
- [ ] Moderação (IA on-device + revisão humana) e recurso.
- [ ] Fluxo de denúncia com SLA e preservação de evidências.
- [ ] Orientação à vítima (Boletim de Ocorrência, 190).

## 8. Pagamentos (CDC)
- [ ] Preço claro e cancelamento fácil.
- [ ] Direito de arrependimento em 7 dias.
- [ ] Emissão de nota fiscal.
- [ ] Regras claras do programa de indicação.

## 9. Documentos públicos
- [ ] Política de Privacidade.
- [ ] Termos de Uso.
- [ ] Política de Cookies.
- [ ] Diretrizes da Comunidade.
- [ ] Aviso de cookies sem dark patterns.

## 10. Incidentes
- [ ] Plano de resposta a incidentes.
- [ ] Notificação à ANPD e aos titulares.

## 11. IA
- [ ] Aviso de decisão automatizada (Art. 20) e revisão humana.
- [ ] IA local, sem treinar com dados de usuário.
- [ ] Registro do funcionamento na DPIA.

## Referências oficiais (gratuitas)
- ANPD — guias de cookies, legítimo interesse, segurança e alto risco.
- LGPD — Lei nº 13.709/2018.
- ECA Digital.
- CDC — Lei nº 8.078/1990.
