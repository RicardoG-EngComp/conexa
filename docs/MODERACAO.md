# Moderacao e Diretrizes da Comunidade

## Conteudo estritamente proibido

- Intolerancia e discriminacao por raca, etnia, religiao, genero, orientacao
  sexual, identidade de genero, deficiencia, origem ou condicao social.
- Violencia, ameaca, incitacao, perseguicao ou conteudo grafico.
- Conteudo explicito pornografico.
- Assedio, bullying, doxxing e exposicao de dados pessoais.
- Imagens intimas sem consentimento.
- Qualquer conteudo envolvendo menores de idade.
- Conteudo ilegal, golpes, spam e perfis falsos.
- Provas vazadas, gabaritos durante avaliacao e "faca meu trabalho".

## Denuncias

Categorias no app:

- intolerancia_discriminacao
- violencia_ameaca
- conteudo_sexual_explicito
- assedio
- imagem_nao_consentida
- menor_de_idade
- spam_golpe
- perfil_falso
- outro

Toda denuncia grave pode ocultar automaticamente o conteudo/perfil ate a
revisao do admin.

O canal de **feedback** (bugs e sugestoes) nao substitui a denuncia. Use a
denuncia para conteudo que viole as diretrizes; use o feedback para problemas do
app e ideias de melhoria.

## Aplicacao

1. Conteudo proibido e bloqueado no servidor no momento da publicacao.
2. Denuncias graves ocultam o conteudo imediatamente.
3. Admin revisa e escolhe: ignorar, advertir, remover conteudo, suspender ou
   banir.
4. Reincidencia escala a punicao.
5. Toda acao fica no `audit_log`.

## Contas suspensas ou banidas

- Perfil e conteudo deixam de aparecer no feed/descobrir.
- Envio de posts, comentarios, mensagens e pedidos e bloqueado.
- O usuario ve uma tela de conta suspensa/banida.

## Integridade academica (estudos)

- Proibido prova vazada, gabarito durante avaliacao e trabalho feito por outra
  pessoa.
- Criadores verificados; curadoria; DMCA; remocao.
- Professores podem publicar material oficial e sinalizar conteudo.
- IA deve citar a fonte e nao treinar em dados do usuario.

## Menores (Conexa Escola)

- Produto separado, sem DM, feed, fotos, localizacao ou romance.
- Q&A moderado por professores/admins.
- Pseudonimo; sem contato externo; sem links.
- Politica de protecao de menores e canal para responsaveis.
- LGPD, ECA, ECA Digital e Play Families.

## Decisoes definitivas

Nao serao copiados do X/Threads, em nenhuma fase:

1. Venda de dados.
2. Selo azul pago.
3. Localizacao exata.
4. Bloqueio de prints.
5. Liberdade absoluta para falar o que quiser, inclusive odio e discriminacao.

O Conexa e ambiente de aprendizado. Discurso de odio e discriminacao nao sao
liberdade de expressao; sao violacao de direitos e serao removidos. A moderacao
forte vale para racismo, LGBTfobia, misoginia, capacitismo, xenofobia,
intolerancia religiosa, neonazismo, apologias a tortura/ditadura, ameaca,
assedio, doxxing, CSAM, imagem intima sem consentimento, fraude academica, spam
e perfil falso. Discussao academica de temas sensiveis e permitida com contexto
e respeito; apologia nao e.

## Palavras-chave no servidor

- `content_policy_category` e `enforce_content_policy` bloqueiam termos de odio,
  ameaca, conteudo sexual explicito e assedio antes do insert.
- Posts, comentarios, mensagens, perfis e pedidos de conversa passam pelo
  trigger; erro esperado: `conteudo_proibido:<categoria>`.
- `moderation_events` registra o bloqueio para revisao admin, sem expor o
  conteudo publicamente.
- A lista de termos deve ser revisada periodicamente para reduzir falso
  positivo e acompanhar variacoes de escrita.

## Midia no feed

- Imagens ficam em bucket privado, com URL assinada e validade curta; nao ha
  URL publica permanente.
- Limites: ate 4 imagens por post; cota de 30 imagens/24h e 500 MB/30d.
- Upload de video esta desativado no MVP por custo; pode voltar como recurso de
  assinante.
- Midia e denunciavel como post; a remocao do post remove o registro e o
  conteudo deixa de ser assinado. Limpeza do objeto no R2 e feita pelo
  `media-gc`.

## Midia no chat

- Imagem (5 MB) e PDF (10 MB) ficam no bucket privado, com URL assinada de 1h e
  assinatura so para participante ativo da conversa.
- Cota: 50 imagens/24h, 20 PDFs/24h e 500 MB/30d.
- Imagem tem miniatura; URL e renovada ao falhar/abrir.
- Upload de video esta desativado no MVP.
- Mensagem com midia e denunciavel; apagar para todos limpa o ponteiro e as
  reacoes. Limpeza do objeto no R2 e feita pelo `media-gc`.
- Grupo de chat exige conexao aceita, titulo e participantes ativos; sem
  anonimato e sem E2EE no MVP para preservar a moderacao.

## Q&A de estudos

- Perguntas e respostas passam pelas diretrizes e por palavras-chave; erro
  esperado: `conteudo_proibido:<categoria>`.
- Autor da pergunta aceita uma resposta; voto e unico por usuario/resposta.
- Denuncia continua pelo canal normal; admin pode remover a pergunta/resposta.
- Nao e espaco para prova vazada, gabarito durante avaliacao ou trabalho feito
  por outra pessoa.

## Apelacoes e contato

- O usuario pode solicitar revisao pelo app ou pelo email de suporte.
- Toda denuncia tem status visivel ao denunciante (`open`, `reviewing`,
  `resolved`, `dismissed`).
- Quando a denuncia for encerrada, o denunciante pode apresentar uma apelacao
  unica pelo app; o admin registra o resultado.
- Prazo alvo no beta: 24 a 48 horas para denuncias.
- Casos de risco de vida: orientar autoridades e servicos de emergencia.

## Retencao

- Denuncias e evidencias: pelo tempo necessario para seguranca e obrigacoes
  legais, com acesso restrito.
- Feedbacks e prints: vinculados a conta; apagados na exclusao. Podem ser
  removidos antes disso para moderacao ou limpeza.
- Dados de conta: excluidos a pedido, salvo obrigacoes legais.
