# Publicação de artigos no LinkedIn pessoal

## Objetivo

Permitir que o administrador transforme um artigo já salvo em uma publicação para seu perfil pessoal do LinkedIn. A IA gera um texto no idioma do artigo, o administrador revisa e pode editar o conteúdo, e a publicação só acontece após confirmação explícita.

## Escopo

Incluído:

- conectar um único perfil pessoal do LinkedIn por OAuth 2.0;
- gerar um texto para LinkedIn a partir do título, corpo e URL pública do artigo;
- preservar o idioma predominante do artigo;
- mostrar um preview editável antes da publicação;
- publicar no LinkedIn somente após confirmação;
- registrar estado, resposta externa e erros;
- impedir uma segunda publicação acidental do mesmo artigo.

Fora do escopo:

- publicação automática ao criar ou atualizar um artigo;
- páginas empresariais do LinkedIn;
- agendamento, analytics, imagens geradas ou outras redes sociais;
- republicação de um artigo já publicado;
- introdução de uma fila de jobs.

## Experiência do administrador

O recurso fica disponível na edição de um artigo já persistido. Um artigo novo precisa ser salvo antes, pois a geração inclui sua URL pública. Se houver alterações não salvas no formulário, a geração fica desabilitada até o artigo ser salvo, garantindo que o texto do LinkedIn corresponda ao conteúdo acessível pelo link.

1. O administrador acessa a edição do artigo.
2. Se não houver uma conexão válida, a seção mostra `Conectar LinkedIn`.
3. Após a conexão, `Gerar post para LinkedIn` envia título, corpo e URL pública ao gerador.
4. O LiveView apresenta o texto em um campo editável, junto do idioma detectado.
5. `Publicar no LinkedIn` abre uma confirmação final.
6. Após a confirmação, a aplicação publica no perfil conectado e exibe sucesso ou erro.
7. Depois do sucesso, a interface mostra a data e o identificador da publicação e desabilita uma nova publicação para o mesmo artigo.

Gerar o preview nunca publica conteúdo. Editar o preview não altera o artigo original.

## Arquitetura

### Contexto `Alchemistdrops.Social`

O novo contexto será a interface usada pelo LiveView. Ele coordena geração, conexão e publicação sem colocar chamadas HTTP ou regras de estado na camada de apresentação.

Operações públicas esperadas:

- obter o compartilhamento de um artigo;
- gerar ou regenerar um draft antes da publicação;
- atualizar o texto editado;
- publicar um draft confirmado;
- consultar o estado da conexão pessoal do LinkedIn.

### `LinkedInContentGenerator`

Usará a integração OpenRouter já existente por meio de um cliente isolado e configurável. O prompt recebe somente o título, o Markdown do artigo e a URL pública.

A resposta será estruturada e validada com:

- `language`: idioma identificado;
- `text`: publicação pronta para edição.

O texto deve:

- permanecer no idioma predominante do artigo;
- resumir a ideia central sem reproduzir o artigo inteiro;
- não inventar fatos, resultados ou opiniões;
- usar tom profissional e natural para um perfil pessoal;
- terminar com uma chamada para leitura e a URL pública;
- respeitar o limite de 3.000 caracteres do LinkedIn.

Resposta inválida, vazia ou acima do limite será tratada como erro de geração e não substituirá um draft válido já existente.

### `LinkedInClient`

Encapsulará OAuth 2.0 e a Posts API atual do LinkedIn usando `Req`.

- autorização de membro com os escopos `openid`, `profile` e `w_member_social`;
- callback autenticado pela sessão administrativa e protegido por `state` contra CSRF;
- identificação do membro autenticado por OpenID Connect para formar o URN de autor;
- publicação em `POST https://api.linkedin.com/rest/posts`;
- headers de versão e `X-Restli-Protocol-Version` exigidos pela API;
- autor configurado com o URN do membro autenticado;
- conteúdo do tipo artigo apontando para a URL pública.

O client retorna resultados normalizados, sem expor detalhes de `Req` ao contexto.

### Persistência

`linkedin_connections` guardará a única conexão pessoal:

- `member_urn`;
- access token criptografado;
- expiração do token;
- timestamps.

O token será criptografado com uma chave dedicada fornecida pelo ambiente, usando as primitivas criptográficas já disponíveis na aplicação e sem adicionar uma biblioteca externa. Tokens nunca serão enviados ao LiveView nem escritos em logs. Caso o token expire e não exista renovação disponível para a aplicação, a interface solicitará uma nova conexão.

`linkedin_post_shares` terá uma relação única com `posts`:

- `post_id` com índice único;
- `status`: `draft`, `publishing`, `published` ou `failed`;
- `language`;
- `generated_text`;
- `edited_text`;
- `linkedin_post_urn`;
- `published_at`;
- `error_message` sanitizado;
- timestamps.

O texto efetivamente publicado será `edited_text` quando presente; caso contrário, `generated_text`.

## Fluxo de dados

### Geração

O LiveView solicita a geração ao contexto. O contexto monta a URL pública com as rotas da aplicação, chama o gerador e grava o resultado como `draft`. Uma nova geração é permitida apenas enquanto o registro não estiver `published`.

### Confirmação e publicação

Ao confirmar, o contexto faz uma transição atômica de `draft` ou `failed` para `publishing`. Apenas a requisição que conseguir essa transição chama o LinkedIn, reduzindo o risco de duplo clique ou chamadas concorrentes.

Em sucesso, o registro recebe `published`, o URN retornado e `published_at`. Em falha, recebe `failed` e uma mensagem segura; o texto permanece disponível para nova tentativa. Uma publicação marcada como `published` não pode ser enviada novamente nesta primeira versão.

A chamada será síncrona e terá timeout explícito. O botão fica desabilitado enquanto o evento está em andamento. Não será adicionada infraestrutura de background jobs nesta entrega.

## Configuração

Variáveis de ambiente:

- `LINKEDIN_CLIENT_ID`;
- `LINKEDIN_CLIENT_SECRET`;
- `LINKEDIN_REDIRECT_URI`;
- `LINKEDIN_API_VERSION`;
- `LINKEDIN_TOKEN_ENCRYPTION_KEY`.

Em produção, todas essas variáveis são obrigatórias para habilitar a integração. A ausência de configuração desabilita a conexão e apresenta uma mensagem administrativa clara, sem afetar a criação ou leitura de artigos.

## Tratamento de erros

- Falha da IA: manter o último draft válido e permitir gerar novamente.
- OAuth recusado ou `state` inválido: não persistir credenciais e informar a falha.
- Token ausente ou expirado: solicitar reconexão antes de publicar.
- Rejeição, rate limit ou timeout do LinkedIn: marcar como `failed`, preservar o texto e permitir retry manual.
- Confirmação repetida ou concorrente: recusar quando o estado já for `publishing` ou `published`.
- Resposta externa inesperada: registrar detalhes técnicos sanitizados no log e mostrar uma mensagem genérica na interface.

## Segurança

- Rotas de conexão e ações do LiveView permanecem sob a sessão administrativa existente.
- OAuth usa `state` de uso único associado à sessão.
- Client secret e chave de criptografia ficam somente no ambiente.
- Access tokens são criptografados em repouso e redigidos de logs e erros exibidos.
- O corpo enviado à IA é tratado como conteúdo, nunca como instrução para alterar regras do prompt.

## Testes

### Unidade

- geração no mesmo idioma para artigos em português e inglês;
- validação de resposta vazia, malformada e acima de 3.000 caracteres;
- montagem da requisição da Posts API e normalização de sucesso e erros;
- criptografia e descriptografia do token sem exposição em inspeção ou mensagens.

### Contexto e banco

- criação e regeneração de draft;
- persistência do texto editado;
- transições `draft -> publishing -> published` e `publishing -> failed`;
- bloqueio de publicação duplicada e garantia única por artigo;
- preservação do draft em falhas externas.

### Web

- botão disponível somente para artigo persistido, sem alterações pendentes, e administrador autenticado;
- estado de conexão e retorno do OAuth;
- preview gerado, edição e confirmação explícita;
- loading, sucesso, erro, retry e estado já publicado;
- criação e atualização normais de artigos continuam funcionando sem configuração do LinkedIn.

Os testes usarão clients configuráveis/fakes; nenhuma chamada real à OpenRouter ou ao LinkedIn será feita na suíte.

## Critérios de aceitação

- Um administrador conecta seu perfil pessoal e gera um preview para um artigo salvo.
- O preview usa o idioma predominante do artigo e contém a URL pública.
- O administrador consegue editar o texto antes de confirmar.
- Nenhum conteúdo chega ao LinkedIn antes da confirmação explícita.
- Uma confirmação bem-sucedida publica no perfil conectado e registra o URN e a data.
- Falhas preservam o texto e permitem retry sem afetar o artigo.
- O mesmo artigo não é publicado duas vezes acidentalmente.
- Sem configuração ou conexão do LinkedIn, o restante do blog continua operando normalmente.
