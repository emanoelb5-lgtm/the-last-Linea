# Continuidade de The Last Linea

## Capítulo I — A floresta que devolve

O jogador conhece um homem adulto, ainda sem nome, que desperta com uma lâmina e uma lanterna. A floresta morta guarda inscrições escritas pela própria mão dele. Portas devolvem seu corpo à clareira; árvores riscadas e lembranças sobrevivem. A montanha forma um cerco físico e narrativo. Ao tocar a fenda, uma voz o chama por um nome que ele não reconhece.

### Regras de continuidade

- O homem não recebe um nome definitivo neste capítulo.
- O motivo dos retornos permanece um mistério.
- Portas não apagam XP, marcas, armadilhas desarmadas nem memórias.
- Não há fome, coleta obrigatória de alimento ou crafting nesta versão.
- As três memórias são opcionais; o capítulo pode ser concluído sem elas.
- A fenda surge no trecho da montanha que o jogador encontra primeiro e conserva essa posição no salvamento.
- Concluir o capítulo concede XP uma vez e permite continuar explorando.

## Possível Capítulo II — A voz do outro lado

Gancho ainda aberto para decisão criativa: a passagem leva a uma estação abandonada dentro da montanha. Uma pessoa conhece o viajante, mas reage como se ele já tivesse vindo muitas vezes. O jogador começa a confrontar a diferença entre lembrar e reconhecer.

Não está implementado. O capítulo seguinte será desenvolvido separadamente com Emanuel.

## Arquitetura para continuar

| Arquivo | Responsabilidade |
|---|---|
| `scripts/game.gd` | Fluxo narrativo, câmeras, menus, HUD e regras de interação do capítulo I |
| `scripts/forest.gd` | Mundo determinístico, árvores, montanhas, portas, pedras e armadilhas |
| `scripts/player.gd` | Movimento, colisão, animação e esquiva |
| `scripts/state.gd` | Salvamento versionado, estatísticas e configurações |
| `scripts/updater.gd` | Consulta de releases, download e verificação do APK |
| `native-updater/` | FileProvider e encaminhamento ao instalador do Android |
| `scripts/art.gd` | Malhas e materiais originais |
| `scripts/sound.gd` | Ambiência e efeitos sintetizados |

Ao adicionar um capítulo, extrair o fluxo de `game.gd` para cenas de capítulo independentes e migrar o salvamento por versão de esquema, conservando os dados anteriores. Não basta substituir o arquivo de save por um formato incompatível.

## Verificação física a fazer no Android

Os testes automatizados não substituem uma sessão no telefone. Medir FPS, temperatura e consumo no Galaxy A56; conferir câmera e movimento simultâneos com dois dedos; colocar o app em segundo plano e retomar; atualizar a versão N para N+1 sem desinstalar e confirmar que marcas/XP continuam; testar internet interrompida e permissão de instalação recusada. Ajustar renderização e alcance de sombras com essas medidas.
