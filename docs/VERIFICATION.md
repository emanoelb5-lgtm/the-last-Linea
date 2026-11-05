# Verificação da versão 0.3 — O viajante

## Falha anterior e correções

O APK público **v0.2.0-build.5 / 1005** foi instalado e aberto em Android 15, imagem Google APIs x86_64 com tradução ARM64. O processo fechou durante a abertura, com `SIGSEGV` na thread `AudioTrack`.

- Primeira reprodução: [Actions 42081518721](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42081518721). O backend gráfico antigo do emulador também apresentava erros de compilação de shaders.
- Segunda reprodução usando ANGLE/SwiftShader: [Actions 42083219483](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42083219483). Os erros de shader desapareceram, mas o fechamento no áudio permaneceu.
- A resolução dos endereços com os símbolos oficiais correspondentes da engine apontou `AudioStreamPlaybackResampled::mix`, `audio_stream.cpp:222`, chamado por `AudioServer::_mix_step`, `_driver_process` e `AudioDriverOpenSL::_buffer_callback`: [diagnóstico de símbolos](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42084696523).

A versão 0.3 substitui os buffers WAV sintetizados durante a abertura por assets Ogg a 48 kHz, começa a ambientação após o primeiro quadro e garante tamanho válido para o SubViewport antes de adicioná-lo à cena. A vinheta também passou a usar limites de `smoothstep` em ordem definida. Isso não identifica, por si só, a causa exata em um telefone físico sem seu log.

## Verificações do código e do visual

- **52 verificações de integração**, sem falhas: exploração, portas, montanha em oito direções, armadilhas, corte, desarme, pausa, câmera, capítulo, salvamentos e atualizador; incluem dimensões iniciais válidas, rig humano, normais das malhas e importação do áudio.
- **3 testes de preparação de release**, sem falhas.
- Capturas reais renderizadas em OpenGL, **1280 × 720 (16:9)**: abertura, exploração, corte, marca, porta, configurações e personagem visto de frente. O corpo usa volumes afunilados, rosto oval, mãos, polegares, cotovelos e joelhos; o aspecto pixelado vem da renderização e dos materiais.
- Mesmo esquema de salvamento (1), pacote `online.b5solucoes.thelastlinea.preview` e identidade de assinatura de teste das versões anteriores.

## Publicação Android

O workflow instala e executa o próprio APK ARM64 antes de publicar. Exige o primeiro quadro renderizado, toca no botão de novo jogo, espera a cutscene e a exploração, envia movimento por toque e volta do segundo plano sem recriar o processo. Logs e capturas são preservados nos artefatos. A versão não é publicada se essa etapa falhar.

O desempenho e a instalação no Galaxy A56 físico continuam pendentes. Emulação com tradução ARM64 não mede FPS, temperatura nem o comportamento de todos os drivers reais.
