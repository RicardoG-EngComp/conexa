# Princípios do projeto

> **JAMAIS escolheremos um caminho apenas por ser “mais simples”. Faremos apenas o que for melhor e mais seguro, respeitando os limites orçamentários do projeto (praticamente zero).**

Este princípio vale para **produto, dados, privacidade, segurança, infraestrutura e código**.

## O que isso significa na prática
- **Segurança no servidor**, não só na interface: RLS, triggers, RPCs e validação de permissões no banco.
- **Privacidade por padrão**: mínimo de dados, visibilidade explícita, nada exposto sem necessidade.
- **Bloqueios e restrições reais**: se algo não pode acontecer, o banco impede (não apenas o app).
- **Toda decisão precisa ser justificada por segurança/qualidade**, não por conveniência.
- **Trade-offs documentados**: quando houver escolha, registrar o motivo.
- **Orçamento ~zero**: priorizar soluções gratuitas/open-source e free tiers, sem sacrificar segurança.
