# Instruções para agentes/planejamentos

## Princípio inegociável
> **JAMAIS escolheremos um caminho apenas por ser “mais simples”. Faremos apenas o que for melhor e mais seguro, respeitando os limites orçamentários do projeto (praticamente zero).**

Aplique isso a produto, dados, privacidade, segurança, infraestrutura e código:
- Segurança e regras de acesso devem ser aplicadas **no servidor** (RLS, triggers, RPCs), não só na UI.
- Toda decisão precisa ser justificada por **segurança/qualidade**, não por conveniência.
- Trade-offs devem ser documentados.
- Orçamento é praticamente zero: usar soluções gratuitas/open-source/free tiers, sem abrir mão de segurança.

Consulte também `docs/PRINCIPIOS.md`.
