# Verificação da primeira versão jogável

Release: **v0.1.0-build.3** · versão Android **1003** · ARM64.
Commit de código: `59105e2b18f73a05821ce22f283fe57ec3ffd3ac`.

## Resultados observados

- Workflow [Android · capítulo I](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42054677408): **success**.
- **39 verificações automatizadas de integração**, sem falhas, executadas no Godot 4.6.3. Incluem movimento físico, abertura/visibilidade, dois toques simultâneos, marcação sem XP duplicado, armadilhas e esquiva, portas, oito direções de descoberta da montanha, descanso, salvamento, final e regras de segurança do manifesto de atualização.
- APK publicado baixado e comparado com `update.json`: tamanho e SHA-256 conferem.
- `apksigner verify`: assinatura APK v2 válida, RSA 2048. Esta é a identidade pública de TESTE documentada no README.
- `aapt`: pacote `online.b5solucoes.thelastlinea.preview`, Android mínimo API 24, alvo API 36, orientação horizontal e ponte nativa de atualização presente.
- Atualizador real executado no Godot desktop simulando um código de versão anterior: consulta da release, leitura do manifesto, download integral do APK e SHA-256 **passaram**. Esse teste usou a rede disponível no ambiente de desenvolvimento; o aplicativo distribuído usa HTTPS normal, sem proxy embutido.
- Capturas reais em **1280 × 720 (16:9)**: abertura, exploração e porta. São renderizações do jogo, sem composição ilustrativa externa.

APK: **73759860 bytes**.

```text
SHA-256: 54336d3e7e9869024cf17b522c3406976fbfac7a0b572dd09571c44a74f70288
```

## Limites desta validação

A instalação e o desempenho em um telefone Android físico ainda não foram observados. Conferir no Galaxy A56 o comportamento do instalador, a atualização da versão N para N+1 sem desinstalar, os dois dedos na tela, o retorno do segundo plano, a fluidez e a temperatura. Os testes no Godot desktop e a verificação do APK não comprovam FPS no telefone.

Não há capítulo II, combate ou inimigos nesta versão. As dificuldades do primeiro capítulo são orientação, portas de retorno e armadilhas. O projeto já tem progressão e persistência para os próximos capítulos.
