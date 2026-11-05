# Verificação da versão 0.3 — O viajante

Release: **[v0.3.0-build.12](https://github.com/emanoelb5-lgtm/the-last-Linea/releases/tag/v0.3.0-build.12)** · versão Android **1012**.
Código compilado: `6774e4effcd5d2ec0f3cb9557ddba5cde48810b0`.

## Resultado observado

[GitHub Actions 42092419736](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42092419736): **success**.

- **54 verificações de integração** e **3 testes de preparação de release**, sem falhas.
- O próprio APK ARM64 publicado foi instalado em Android 15, imagem Google APIs x86_64 com tradução ARM64. O teste abriu o menu, iniciou o capítulo, aguardou a cutscene, entrou na exploração e enviou movimento por toque.
- O teste colocou o app em segundo plano e o trouxe de volta sem trocar de processo. Exigiu uma imagem visível, identificou o botão **Voltar à floresta**, tocou nele e confirmou a retomada da exploração com outra imagem visível.
- Os registros confirmam `LINEA_BOOT_READY`, `LINEA_INTRO_READY`, `LINEA_PLAY_READY`, `LINEA_BUTTON RESUME_GAME`, `LINEA_PLAY_RESUMED` e `PASS: Android startup, cutscene, gameplay, touch and background/resume`.
- Não houve erro de script, erro da árvore da cena ou falha nativa nessa execução. O teste rejeita telas uniformes/pretas mesmo com o processo aberto.
- As capturas foram revisadas visualmente: [exploração após retornar](screenshots/09-android.webp) e [menu de pausa](screenshots/10-android-pausa.webp). Todas têm **1280 × 720 (16:9)**. Os artefatos incluem também menu, cutscene, início da exploração, logs e verificação do pacote.

O modelo novo também foi renderizado em OpenGL no desktop: cabeça oval, rosto, pescoço, mãos com polegares, tronco afunilado, cotovelos e joelhos articulados. O corpo usa volumes anatômicos, sem cubos; o aspecto pixelado vem da baixa resolução e dos materiais. [Personagem visto de frente](screenshots/08-personagem-humano.webp).

## Falhas corrigidas

O APK anterior **v0.2.0-build.5 / 1005** fechou durante a abertura no Android de teste, com `SIGSEGV` na thread `AudioTrack`. A reprodução com ANGLE eliminou os erros gráficos específicos do primeiro backend de emulação, mas manteve o fechamento de áudio. Os símbolos oficiais apontaram `AudioStreamPlaybackResampled::mix`, `audio_stream.cpp:222`, chamado pelo mixer e pelo driver OpenSL. Referências: [reprodução](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42083219483) e [símbolos](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42084696523).

A versão 0.3 substitui os buffers WAV sintetizados durante a abertura por assets Ogg a 48 kHz e começa a ambientação após o primeiro quadro. O SubViewport recebe dimensões válidas antes de entrar na cena, mesmo enquanto o Android informa tamanho nulo; a vinheta passou a usar limites definidos de `smoothstep`.

A revisão das capturas também encontrou uma tela preta após o retorno do segundo plano, acompanhada de `EGL_BAD_SURFACE`. A camada Java passou a permitir a recuperação da superfície EGL sem descartar o contexto gráfico. A origem, o SHA-256 do fonte original e a alteração estão descritos em [native-compat/README.md](../native-compat/README.md). A licença Apache-2.0 acompanha o código e a tela de licenças do jogo. Os dois binários nativos oficiais da engine foram comparados com o build anterior e continuam **idênticos byte a byte**.

O menu de pausa tentava adicionar controles enquanto a árvore estava bloqueada pela propagação da notificação do Android. Sua criação e o tratamento de Voltar passaram a ocorrer depois da propagação; o botão Voltar deixa de provocar a saída automática. Dois testes propagam essas notificações pela árvore e conferem a presença do menu e a retomada.

O teste de Android agora aguarda a estabilização dos recursos do primeiro boot do emulador e dispensa o tutorial nativo de tela cheia antes de interagir com o jogo. A publicação exige tanto o processo vivo quanto a imagem restaurada e a interação de retomada.

## Integridade e compatibilidade

O APK público foi baixado separadamente e comparado com `update.json`, com o arquivo testado no Actions e com o digest do GitHub. Os valores coincidiram:

- Tamanho: **73.882.963 bytes**.
- SHA-256: `83eecb0f5dcc2afa1edd113328116f9a0b03d255a82c195ee12c5dfd971f4120`.
- Assinatura v2 e certificado anterior: `a669a74339740c39ac53d68b81508f93735757aadf11f10c0ca3e4f838ebb20d`.
- Pacote `online.b5solucoes.thelastlinea.preview`, ARM64, orientação horizontal, API mínima 24, alvo 36 e ponte nativa de atualização verificados no APK.
- Presença da correção de superfície confirmada no DEX pelo verificador de empacotamento.
- Mesmo esquema de salvamento (1): vida, XP, marcas, memórias, armadilhas, montanha e progresso continuam compatíveis. Atualize por cima da versão anterior para manter os dados locais.

## Limite da validação

Não houve acesso a um Android físico. O teste emulado confirma abertura, capítulo, retorno e interação nesse ambiente; não mede FPS, temperatura nem todos os drivers do Galaxy A56. O fechamento do APK anterior foi reproduzido no teste, mas sem um log do telefone não se identifica com certeza o ponto exato da falha naquele aparelho.
