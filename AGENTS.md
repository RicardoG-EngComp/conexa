# Instruções para agentes/planejamentos

## Princípio inegociável
> **JAMAIS escolheremos um caminho apenas por ser “mais simples”. Faremos apenas o que for melhor e mais seguro, respeitando os limites orçamentários do projeto (praticamente zero).**

Aplique isso a produto, dados, privacidade, segurança, infraestrutura e código:
- Segurança e regras de acesso devem ser aplicadas **no servidor** (RLS, triggers, RPCs), não só na UI.
- Toda decisão precisa ser justificada por **segurança/qualidade**, não por conveniência.
- Trade-offs devem ser documentados.
- Orçamento é praticamente zero: usar soluções gratuitas/open-source/free tiers, sem abrir mão de segurança.

Consulte também `docs/PRINCIPIOS.md`.

## Backend (obrigatório)

Antes de alterar migrations, RLS, RPCs, triggers, Edge Functions ou Storage,
**leia `docs/BACKEND-INVARIANTES.md`**. Ele documenta por que cada regra existe e
o que não pode ser alterado sem quebrar feed, grupos, conversas, conexões,
denúncias, perfis, notificações e storage.

- Toda mudança que afete um invariante deve **atualizar o documento** e os
  **testes de integração** correspondentes.
- Não reintroduza policies amplas, convites por link, auto-hide com menos de 3
  denunciantes ou validações apenas no cliente.
- Mudou RPC/assinatura/erro esperado? Atualize `app/` e os testes no mesmo PR.
- Rode `flutter analyze` e a suíte de integração (`-j 1`, com credenciais) antes
  de considerar a mudança concluída.
