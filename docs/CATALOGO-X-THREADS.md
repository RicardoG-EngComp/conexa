# Catálogo de funções do X e do Threads

> Documento interno de produto. Base: funções públicas do X e do Threads em
> novembro de 2026. Recursos regionais, experimentais ou descontinuados podem
> variar. O objetivo é decidir o que faz sentido implementar no Conexa, com
> custo e risco jurídico explícitos.

## Como ler

- **Conexa:** Tem / Parcial / Não.
- **Custo:** Baixo (UI + tabela/coluna + RLS), Médio (storage, push, jobs,
  busca, analytics, chat em grupo) e Alto (vídeo/live/chamadas, fediverso, IA,
  moderação 24/7, pagamentos).
- **Risco:** Livre (conceito genérico), Adaptar (seguro, mas exige cuidado de
  privacidade, moderação ou custo) e Evitar (não implementar por princípio,
  segurança ou legalidade).
- Copiar a **função** é diferente de copiar a **expressão**. O que não copiar
  está em `docs/NAO-COPIAR.md`.

## Decisões de produto já registradas

1. Prioridade recomendada: P0 privacidade/confiança; P1 feed; P2 chat;
   P3 descoberta; P4 grupos/estudos; P5 experimental.
2. Upload de vídeo está pausado por custo. Imagens e PDF seguem no MVP; vídeo
   pode voltar como recurso de assinante no futuro.
3. Sem E2EE no MVP do chat em grupo; moderação server-side é obrigatória.
4. Moderação começa com regras + denúncia + revisão humana + palavras-chave.
5. Não serão copiados: venda de dados, selo azul pago, localização exata,
   bloqueio de prints e liberdade absoluta para ódio/discriminação.
6. Convite de grupo continua somente in-app; sem link copiável.
7. Sem anúncios e sem venda de dados.

## 1. Conta, perfil e identidade

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Cadastro por e-mail/telefone | Sim | Sim | Tem | Baixo | Livre |
| Login social (Google/Apple/Instagram) | Sim | Sim | Não | Médio | Adaptar |
| Handle @ único | Sim | Sim | Não | Baixo | Livre |
| Nome, bio, foto | Sim | Sim | Tem | Baixo | Livre |
| Links no perfil (até 5) | Sim | Sim | Não | Baixo | Adaptar (spam) |
| Banner/capa | Sim | Não | Não | Baixo | Livre |
| Múltiplas contas | Sim | Sim | Não | Médio | Adaptar (abuso) |
| Perfil privado | Sim | Sim | Tem | Baixo | Livre |
| Verificação/selo | Sim (pago) | Sim (Meta Verified) | Parcial (institucional/18+) | Médio | Adaptar; não vender |
| Badges/conquistas | Parcial | Não | Tem | Baixo | Livre |
| Localização no perfil | Sim | Sim | Não | Baixo | Evitar (exata) |
| Pronomes/aniversário | Parcial | Parcial | Não | Baixo | Adaptar |
| Trocar nome/handle | Sim | Sim | Parcial | Baixo | Livre |
| Perfil público na web/SEO | Sim | Sim | Não | Médio | Adaptar (privacidade) |
| Importar seguidores/contatos | Sim | Sim | Não | Alto | Evitar (privacidade) |

## 2. Publicação e formatos

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Post curto | Sim | Sim | Tem (2.000) | Baixo | Livre |
| Post longo | Sim (Premium) | Sim (snippet) | Parcial | Baixo | Livre |
| Fotos no post | Sim | Sim | Não | Médio | Adaptar |
| Vídeo curto | Sim | Sim | Não | Alto | Adaptar |
| Vídeo longo | Sim | Sim | Não | Alto | Adaptar |
| GIF | Sim | Sim | Parcial (chat) | Médio | Adaptar (licenças) |
| Link preview | Sim | Sim | Não | Médio | Adaptar (SSRF) |
| Carrossel | Sim | Sim | Não | Médio | Adaptar |
| Áudio/música no post | Parcial | Sim | Não | Alto | Adaptar (direitos) |
| Enquete | Sim | Sim (24h) | Não | Baixo | Livre |
| Sequência de posts (thread) | Sim | Sim | Parcial (respostas 3 níveis) | Médio | Livre |
| Citação | Sim | Sim | Tem | Baixo | Livre |
| Repost simples | Sim | Sim | Não | Baixo | Livre |
| Editar post | Sim (Premium) | Sim (15 min) | Não | Baixo | Livre |
| Excluir post | Sim | Sim | Tem | Baixo | Livre |
| Fixar post no perfil | Sim | Sim (1) | Não | Baixo | Livre |
| Rascunhos | Sim | Sim (100) | Não | Baixo | Livre |
| Agendamento | Sim | Sim | Não | Médio | Livre |
| Arquivar posts | Sim | Parcial | Não | Baixo | Livre |
| Alt text | Sim | Sim | Não | Baixo | Livre |
| Spoiler/content warning | Parcial | Sim | Não | Baixo | Livre |
| Post efêmero (ghost 24h) | Não | Sim | Não | Médio | Adaptar (moderação) |
| Marcação de conteúdo sensível | Sim | Sim | Parcial | Médio | Adaptar |
| Localização no post | Sim | Sim | Não | Baixo | Evitar (exata) |
| Marcar pessoas no post | Sim | Sim | Não | Baixo | Adaptar (consentimento) |
| Lembrete/agendamento de post | Sim | Sim | Não | Baixo | Livre |

## 3. Feed, busca e descoberta

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Feed Para Você | Sim | Sim | Tem | Médio | Livre |
| Feed Seguindo/Conexão | Sim | Sim | Tem | Baixo | Livre |
| Feed cronológico | Sim | Sim | Parcial | Baixo | Livre |
| Atualização manual/pull-to-refresh | Sim | Sim | Parcial | Baixo | Livre |
| Scroll infinito | Sim | Sim | Tem | Baixo | Livre |
| Listas de contas | Sim | Não | Não | Baixo | Livre |
| Feeds customizados | Não | Sim | Não | Médio | Livre |
| Fixar feeds/colunas | Sim (Pro) | Sim (web) | Não | Médio | Livre |
| Trends/Explore | Sim | Parcial (regiões) | Não | Médio | Adaptar (moderação) |
| Busca global de posts | Sim | Sim | Não | Médio | Livre |
| Busca de pessoas | Sim | Sim | Tem | Baixo | Livre |
| Busca de hashtags/tópicos | Sim | Sim | Parcial | Baixo | Livre |
| Filtros de busca (data/mídia/conta) | Sim | Parcial | Não | Médio | Livre |
| Notificações de curtida/comentário/menção | Sim | Sim | Parcial | Baixo | Livre |
| "Não interessado" | Sim | Sim | Parcial (ocultar) | Baixo | Livre |
| "Por que vejo isso" | Sim | Sim | Tem | Baixo | Livre |
| Controle do algoritmo | Parcial | Sim (Your Algo) | Parcial | Médio | Adaptar |
| Notas da comunidade | Sim | Não | Não | Alto | Adaptar (moderação) |
| Tradução de posts | Sim | Sim | Não | Médio | Adaptar (API/custo) |
| Feed de vídeo imersivo | Sim | Sim | Não | Alto | Adaptar |
| Seguir tópico | Sim | Sim | Parcial | Baixo | Livre |
| Feed local/campus | Parcial | Parcial | Parcial | Médio | Livre |

## 4. Interações sociais

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Curtir | Sim | Sim | Tem | Baixo | Livre |
| Comentar/responder | Sim | Sim | Tem | Baixo | Livre |
| Respostas aninhadas | Sim | Sim | Tem (3 níveis) | Baixo | Livre |
| Curtir comentário | Sim | Sim | Não | Baixo | Livre |
| Responder comentário | Sim | Sim | Parcial | Baixo | Livre |
| Compartilhar post | Sim | Sim | Parcial | Baixo | Livre |
| Compartilhar via link | Sim | Sim | Não | Baixo | Livre |
| Copiar link do post | Sim | Sim | Não | Baixo | Livre |
| Compartilhar no DM | Sim | Sim | Não | Baixo | Livre |
| Compartilhar em grupo | Sim | Sim | Não | Baixo | Livre |
| Menções @ | Sim | Sim | Não | Baixo | Adaptar (spam) |
| Marcar/etiquetar pessoas | Sim | Sim | Não | Baixo | Adaptar (consentimento) |
| Seguir/deixar de seguir pessoas | Sim | Sim | Não (conexões) | Médio | Adaptar (muda modelo social) |
| Seguidores/seguindo | Sim | Sim | Não | Médio | Adaptar |
| Silenciar conversa/post | Sim | Sim | Não | Baixo | Livre |
| Ocultar post | Sim | Sim | Parcial | Baixo | Livre |
| Denunciar post | Sim | Sim | Tem | Baixo | Livre |
| Bloquear autor | Sim | Sim | Tem | Baixo | Livre |

## 5. Mensagens

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| DM 1:1 | Sim (XChat) | Sim | Tem | Baixo | Livre |
| Pedido de mensagem | Sim | Sim | Tem | Baixo | Livre |
| Chat em grupo | Sim | Sim | Não | Médio | Livre |
| Adicionar/remover membros | Sim | Sim | Não | Médio | Livre |
| Fotos/vídeos no chat | Sim | Sim | Não | Alto | Adaptar |
| Arquivos no chat | Sim | Sim | Não | Médio | Adaptar (segurança) |
| Nota de voz | Sim | Sim | Não | Médio | Adaptar |
| Chamada de voz | Sim | Parcial | Não | Alto | Adaptar |
| Chamada de vídeo | Sim | Parcial | Não | Alto | Adaptar |
| Editar mensagem | Sim | Sim | Não | Baixo | Livre |
| Apagar para todos | Sim | Sim | Tem | Baixo | Livre |
| Apagar para mim | Sim | Sim | Tem | Baixo | Livre |
| Mensagens efêmeras | Sim | Parcial | Não | Médio | Adaptar |
| E2EE | Sim (XChat, contestado) | Não | Não | Alto | Adaptar (auditoria) |
| Reações | Parcial | Sim | Não | Baixo | Livre |
| Responder mensagem | Sim | Sim | Não | Baixo | Livre |
| Encaminhar | Sim | Sim | Não | Baixo | Livre |
| Fixar conversa | Sim | Sim | Não | Baixo | Livre |
| Silenciar conversa | Sim | Sim | Não | Baixo | Livre |
| Arquivar conversa | Sim | Sim | Não | Baixo | Livre |
| Indicador digitando | Sim | Sim | Não | Baixo | Livre |
| Visto por último/online | Sim | Sim | Parcial | Baixo | Adaptar (privacidade) |
| Recibos de leitura | Sim | Sim | Parcial | Baixo | Adaptar (privacidade) |
| Busca de conversas | Sim | Sim | Tem | Baixo | Livre |
| Bloquear print | Sim | Não | Não | Baixo | Evitar |
| Stickers/GIF | Sim | Sim | Tem | Médio | Adaptar (licenças) |
| Salas de áudio (Spaces) | Sim | Não | Não | Alto | Adaptar |
| Transmissão ao vivo | Sim | Parcial | Não | Alto | Adaptar |
| Chamada em grupo | Sim | Parcial | Não | Alto | Adaptar |
| Compartilhar tela | Sim | Não | Não | Alto | Adaptar |
| Localização em tempo real no chat | Parcial | Não | Não | Médio | Evitar (exata) |
| Mensagens de sistema/segurança | Sim | Sim | Parcial | Baixo | Livre |

## 6. Grupos e comunidades

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Criar/entrar/sair | Sim | Sim | Tem | Baixo | Livre |
| Grupos públicos/privados | Sim | Sim | Tem | Baixo | Livre |
| Cargos/permissões | Sim | Sim | Tem | Baixo | Livre |
| Convite por link | Sim | Sim | Não (in-app) | Baixo | Evitar link |
| Convite por pessoa | Sim | Sim | Tem | Baixo | Livre |
| Aprovação de entrada | Sim | Sim | Parcial | Baixo | Livre |
| Aprovação/selo oficial | Não | Não | Tem | Baixo | Livre |
| Moderar posts/comentários | Sim | Sim | Tem | Baixo | Livre |
| Seguidores do grupo | Não | Não | Tem | Baixo | Livre |
| Chat do grupo | Sim | Sim | Não | Médio | Livre |
| Eventos do grupo | Não | Não | Não | Médio | Livre |
| Analytics do grupo | Não | Sim | Não | Médio | Adaptar (agregado) |
| Descoberta de grupos | Não | Sim | Tem | Baixo | Livre |
| Regras/flairs/categorias | Não | Sim | Parcial | Baixo | Livre |
| Comunidades locais | Não | Sim | Não | Médio | Adaptar (moderação) |
| Champions/embaixadores | Não | Sim | Parcial (cargos) | Baixo | Livre |
| Convite para evento | Não | Não | Não | Baixo | Livre |
| Lista de membros | Sim | Sim | Tem | Baixo | Livre |
| Remover membro | Sim | Sim | Tem | Baixo | Livre |
| Transferir admin | Sim | Sim | Não | Baixo | Livre |
| Comunidades abertas sem moderação | Descontinuado em 2026 | Sim | Não | Alto | Evitar (spam/ódio) |

## 7. Criador, monetização e plataforma

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Assinatura de criador | Sim | Parcial | Não | Alto | Adaptar (Play Billing) |
| Conteúdo exclusivo para assinantes | Sim | Não | Não | Alto | Adaptar |
| Gorjetas | Sim | Não | Não | Alto | Adaptar (jurídico) |
| Pagamentos/X Money | Sim | Não | Não | Alto | Evitar por agora |
| Anúncios | Sim | Sim | Não | Alto | Evitar (princípio) |
| Revenue sharing | Sim | Parcial | Não | Alto | Evitar no MVP |
| Jobs/vagas | Sim | Não | Não | Médio | Adaptar (futuro B17) |
| API pública | Sim (paga) | Sim | Não | Alto | Adaptar |
| Ferramentas de agendamento | Sim | Sim | Não | Baixo | Livre |
| Analytics de perfil | Sim | Sim | Não | Médio | Adaptar |
| Analytics demográfico | Sim | Sim | Não | Alto | Evitar (LGPD) |
| Link clicks | Sim | Sim | Não | Médio | Adaptar |
| Verificação paga | Sim | Sim | Não | Alto | Evitar |
| Colunas/Pro dashboard | Sim | Sim (web) | Não | Médio | Livre |
| Cross-posting | Parcial | Sim | Não | Médio | Adaptar |
| Podcasts | Sim | Não | Não | Alto | Adaptar |
| Vídeo longo | Sim | Sim | Não | Alto | Adaptar |
| Live | Sim | Parcial | Não | Alto | Adaptar |

## 8. Segurança, privacidade e moderação

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Bloquear | Sim | Sim | Tem | Baixo | Livre |
| Lista de bloqueados | Sim | Sim | Tem | Baixo | Livre |
| Silenciar usuário | Sim | Sim | Não | Baixo | Livre |
| Silenciar palavras/tópicos | Sim | Sim | Não | Baixo | Livre |
| Restringir interações | Sim | Sim | Não | Baixo | Livre |
| Limitar quem responde | Sim | Sim | Não | Baixo | Livre |
| Limitar quem cita | Sim | Sim | Não | Baixo | Livre |
| Limitar quem envia DM | Sim | Sim | Parcial (pedidos) | Baixo | Livre |
| Limitar quem menciona/marca | Sim | Sim | Não | Baixo | Livre |
| Ocultar respostas | Sim | Sim | Parcial | Baixo | Livre |
| Denunciar | Sim | Sim | Tem | Baixo | Livre |
| Status da denúncia | Sim | Parcial | Não | Baixo | Livre |
| Apelação | Sim | Sim | Não | Médio | Livre |
| Auto-hide | Parcial | Parcial | Tem | Baixo | Livre |
| Fila de moderação | Sim | Sim | Tem (admin) | Baixo | Livre |
| Moderação de palavras | Sim | Sim | Parcial | Baixo | Livre |
| Filtro de conteúdo sensível | Sim | Sim | Parcial | Médio | Adaptar |
| Modo silencioso/limite de tempo | Parcial | Sim | Não | Baixo | Livre |
| 2FA | Sim | Sim | Não | Baixo | Livre |
| Chaves de segurança | Sim | Sim | Não | Médio | Livre |
| Sessões/alertas de login | Sim | Sim | Não | Baixo | Livre |
| Exportar dados | Sim | Sim | Não | Médio | Livre (LGPD) |
| Excluir conta | Sim | Sim | Tem | Baixo | Livre |
| Desativar conta temporariamente | Sim | Sim | Não | Baixo | Livre |
| Bloquear screenshots | Sim | Não | Não | Baixo | Evitar |
| Detecção de menores | Parcial | Parcial | Parcial (18+) | Alto | Adaptar |
| Verificação de idade | Parcial | Parcial | Tem | Baixo | Livre |
| Privacidade por padrão | Não | Parcial | Tem | Baixo | Livre |
| Transparência de moderação | Parcial | Parcial | Parcial | Médio | Livre |
| Relatório de transparência | Não | Não | Não | Médio | Livre |
| Denúncia de impersonação | Sim | Sim | Parcial | Baixo | Livre |
| Denúncia de spam | Sim | Sim | Parcial | Baixo | Livre |
| Denúncia de CSAM | Sim | Sim | Parcial | Alto | Adaptar (obrigatório) |
| Denúncia de NCII | Sim | Sim | Parcial | Alto | Adaptar (obrigatório) |
| Linha de crise/saúde mental | Não | Não | Não | Médio | Adaptar |
| Controle parental | Não | Não | Não | Médio | Adaptar (18+) |
| "Não quero ver isso" | Sim | Sim | Parcial | Baixo | Livre |

## 9. IA, fediverso e experimental

| Função | X | Threads | Conexa | Custo | Risco |
|---|---|---|---|---|---|
| Assistente de IA | Sim (Grok) | Sim (Meta AI) | Parcial (coach) | Alto | Adaptar (IA própria) |
| Resumo de posts/trends por IA | Sim | Sim | Não | Alto | Adaptar |
| Tradução por IA | Sim | Sim | Não | Médio | Adaptar |
| Geração de imagem/vídeo | Sim | Sim | Não | Alto | Adaptar |
| Moderação por IA | Sim | Sim | Parcial | Alto | Adaptar |
| Fediverso/ActivityPub | Não | Sim | Não | Alto | Adaptar |
| Ponte com outras redes | Parcial | Sim | Não | Alto | Adaptar |
| "Dear Algo"/controle por linguagem natural | Não | Sim | Não | Alto | Adaptar |
| Acessibilidade por IA (descrição de imagem) | Sim | Sim | Não | Médio | Adaptar |

## 10. Prioridade de implementação

### P0 - Privacidade e confiança
Sessões e alertas de login; exportar dados; silenciar usuário e palavras;
status e apelação de denúncia; controle de quem responde; política de moderação
forte. Custo predominante: baixo.

### P1 - Paridade de feed
Bookmark; repost simples; enquete; edição (15 min); fixar post; rascunhos;
agendamento; alt text; menções; notificações de curtida/comentário/menção;
imagens no feed com moderação e cota. Upload de vídeo pausado por custo.

### P2 - Chat
Chat em grupo; responder mensagem; reações; editar; imagem; fixar, silenciar e
arquivar conversa; indicador digitando. Sem E2EE no MVP.

### P3 - Descoberta
Busca global; listas/feeds; "não interessado"; analytics agregado;
compartilhar link.

### P4 - Grupos e estudos
Chat do grupo; eventos; analytics agregado; Q&A; materiais salvos; avaliações.

### P5 - Hardening e experimental
Hardening: remover 2FA e vídeo, exportação em arquivo, termos administráveis,
mídia agendada, membros do chat, RSVP, busca em comentários, views, anexos de
Q&A e comentário em avaliações. Experimental (áudio/live, fediverso, IA,
monetização) somente com orçamento e revisão jurídica.

## 11. Custos escondidos

- Armazenamento e tráfego de mídia (R2/Supabase).
- Compressão e transcodificação de imagem e vídeo.
- Push (FCM é grátis, mas exige operação e diagnóstico).
- Moderação humana, suporte e apelações.
- Backups, retenção e exclusão.
- Play Store, políticas e revisão jurídica.
- CDN e egress em picos.
- Engenharia e manutenção contínua.

## 12. Vídeo: decisão atual

Upload de vídeo está **desativado no MVP** por custo. Imagens e PDF seguem.
Se voltar, será como recurso de assinante, com:

- limite de duração e tamanho;
- compressão no aparelho antes do upload;
- armazenamento em R2 com cota por usuário;
- streaming progressivo, sem transcodificação multi-bitrate no MVP;
- moderação por denúncia + revisão + palavras-chave;
- URLs assinadas de curta duração e limite de reproduções por sessão;
- remoção de conteúdo proibido e bloqueio de reincidência.

## 13. Status de execução

- **P0 concluído:** mutes de usuário e palavras; controle de respostas;
  status/apelação de denúncia; exportação LGPD; dispositivos conhecidos;
  documentação de catálogo, limites jurídicos e moderação.
- **P1 concluído:** bookmark; repost simples; enquete; edição 15 min; fixar;
  rascunhos; agendamento; alt text; menções; notificações de interação; imagens
  com cota. Upload de vídeo pausado por custo.
- **P2 concluído:** chat em grupo; responder mensagem; reações; edição; mídia
  de imagem/PDF; fixar, silenciar e arquivar; indicador digitando. Sem E2EE.
- **P3 concluído:** busca global de posts; feeds personalizados por tópicos;
  “não interessado”; insights agregados; copiar link via deep link.
- **P4 concluído:** chat do grupo do campus, eventos, analytics de grupo, Q&A,
  materiais salvos e avaliações.
- **P5 hardening concluído:** 2FA e upload de vídeo removidos; exportação em
  arquivo; termos de moderação administráveis; mídia agendada; membros do chat;
  RSVP e lembretes; busca em comentários; views; anexos de Q&A; comentário
  público em avaliações.
- **P5 experimental** (áudio/live, fediverso, IA e monetização) fica para
  depois, com orçamento e revisão jurídica. E2EE fora enquanto houver moderação
  server-side.

