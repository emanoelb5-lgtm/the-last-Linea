# Verificação da versão 0.4 — O despertar

Release: **[v0.4.0-build.13](https://github.com/emanoelb5-lgtm/the-last-Linea/releases/tag/v0.4.0-build.13)** · versão Android **1013**.
Código compilado: `2d3cd80466d1df09663cdb81c534fa8aebf8ac27`.

## Resultado observado

[GitHub Actions 42144564659](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42144564659): **success**.

- **65 verificações de integração** e **3 testes de preparação de release**, sem falhas.
- O APK ARM64 publicado foi instalado em Android 15, imagem Google APIs x86_64 com tradução ARM64. O teste abriu o menu, iniciou o capítulo, aguardou a cutscene completa, entrou na exploração e enviou movimento por toque.
- O teste colocou o app em segundo plano e o trouxe de volta sem trocar de processo. Exigiu uma imagem visível, identificou o botão **Voltar à floresta**, tocou nele e confirmou a retomada da exploração com outra imagem visível.
- Os registros confirmam `LINEA_BOOT_READY`, `LINEA_INTRO_READY`, `LINEA_PLAY_READY`, `LINEA_BUTTON RESUME_GAME`, `LINEA_PLAY_RESUMED` e `PASS: Android startup, cutscene, gameplay, touch and background/resume`.
- Não houve erro de script, erro da árvore da cena ou falha nativa nessa execução. O teste rejeita telas uniformes/pretas mesmo com o processo aberto.
- As capturas do próprio APK foram revisadas visualmente: abertura, [exploração após retornar](screenshots/09-android.webp) e [menu de pausa](screenshots/10-android-pausa.webp). Todas têm **1280 × 720 (16:9)**. Os artefatos do Actions incluem imagens, logs e verificação do pacote.

## Personagem, abertura e câmera

O jovem usa volumes anatômicos afunilados, rosto sem barba, franja escura, mãos, cotovelos, joelhos e tornozelos articulados. O visual pixelado vem da baixa resolução e dos materiais. A abertura de 16 segundos passa por despertar, apoio com as mãos, posição sentada, ajoelhamento, subida e equilíbrio; a lanterna permanece no chão até ser recolhida. O jovem olha ao redor e pergunta em legenda **“— Onde eu estou?”**.

As verificações exercitam 321 poses, conferem posições finitas e contínuas, o joelho perto do solo e o pé de apoio durante a subida. A câmera usa ângulo baixo, limites de inclinação e obstrução pelas árvores. Também foram revisadas renderizações OpenGL de [frente](screenshots/08-personagem-humano.webp), [ajoelhado](screenshots/14-ajoelhado.webp), [perguntando onde está](screenshots/16-onde-estou.webp) e durante a exploração.

## Floresta e final do capítulo

- A encosta fica a **760 m do início**, formando uma floresta com cerca de **1,5 km de diâmetro**. A geometria é carregada em 25 regiões ao redor do jogador; árvores distantes têm menos detalhes e colisões são mantidas próximas ao personagem.
- Os testes percorrem oito direções e verificam que o conjunto de árvores carregadas permanece abaixo de 1.400, sem acumular regiões abandonadas.
- Não há armadilhas a menos de **260 m** nem portas a menos de **410 m** do início. As distâncias de todos os objetos são verificadas automaticamente.
- Chegar ao pé da montanha encerra o capítulo automaticamente, por qualquer direção. Cinco metros antes ainda não encerra. Memórias, portas e quantidade de marcas não bloqueiam o final.
- A descoberta e o encerramento concedem 100 XP ao todo, apenas uma vez. A tela [Ao pé da montanha](screenshots/17-pe-da-montanha.webp) foi revisada em 1280 × 720.
- Marcas são reconstruídas ao descarregar e recarregar uma região. Um teste manual independente confirmou que as **240 posições de árvores anteriores permanecem idênticas**. Também riscou a árvore nova de ID 27876, salvou, recarregou o estado e retornou à região: a marca reapareceu.

O esquema de salvamento continua sendo 1. Vida, XP, marcas, memórias, armadilhas e conclusão anterior permanecem compatíveis. **Continuar** preserva o progresso; **Novo capítulo**, após a confirmação do jogo, reinicia o progresso para assistir à nova abertura.

## Integridade e compatibilidade

O APK público foi baixado separadamente e comparado com `update.json`, com o arquivo testado no Actions e com o digest do GitHub. Os valores coincidiram:

- Tamanho: **73.892.936 bytes**.
- SHA-256: `ae99eea82f74ba3a93c6b4eff12397afc481043a354de2bf06ed98a29cd42b7d`.
- Assinatura v2 e certificado anterior: `a669a74339740c39ac53d68b81508f93735757aadf11f10c0ca3e4f838ebb20d`.
- Pacote `online.b5solucoes.thelastlinea.preview`, ARM64, orientação horizontal, API mínima 24, alvo 36 e ponte nativa de atualização verificados no APK.
- Presença da correção de superfície confirmada no DEX pelo verificador de empacotamento.

As correções de abertura e retorno da versão 0.3 continuam presentes: áudio Ogg a 48 kHz iniciado após o primeiro quadro, SubViewport com dimensões válidas, tratamento adiado da pausa/Voltar e recuperação de superfície EGL. A alteração Java e sua licença estão documentadas em [native-compat/README.md](../native-compat/README.md).

## Limite da validação

Não houve acesso a um Android físico. O teste emulado confirma abertura, capítulo, retorno e interação nesse ambiente; não mede FPS, temperatura nem todos os drivers do Galaxy A56.
