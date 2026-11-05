# Verificação da versão 0.2 — Deixe um sinal

Release: **v0.2.0-build.5** · versão Android **1005** · pacote `online.b5solucoes.thelastlinea.preview`.
Código compilado: `c8d0d7d01fca720929e6cce4364393e8d95e1ed5`.

## Resultados observados

- [GitHub Actions](https://github.com/emanoelb5-lgtm/the-last-Linea/actions/runs/42074160508): **success**. O workflow gerou, verificou e publicou o APK e o manifesto.
- **47 verificações de integração do jogo**, sem falhas. Além do movimento, portas, montanha em oito direções, salvamento e final, cobrem corte com recompensa somente ao terminar, pausa da ação, cancelamento por dano, desarme com duração e proteção da câmera durante a suavização.
- **3 testes de preparação de release**, sem falhas: propagação da versão informada, recompilação sem duplicar dados de assinatura e rejeição de metadados inválidos.
- Leitura de progresso no formato anterior: vida, XP, marcas, memórias, armadilhas, montanha e posição continuam compatíveis. O esquema de salvamento continua na versão 1.
- O verificador do APK no Actions confirmou assinatura v2, identificação como jogo, orientação horizontal, ARM64, versões do Android e presença da ponte nativa de instalação.
- O arquivo publicado foi baixado separadamente e teve tamanho e SHA-256 comparados com `update.json`.
- O atualizador real do jogo, executado no Godot desktop simulando o build anterior **1004**, encontrou a versão **1005**, baixou todo o APK e confirmou o SHA-256. O teste utilizou a rede do ambiente de desenvolvimento; nenhum proxy foi incorporado ao aplicativo.
- Capturas reais da aproximação, corte e marca concluída foram renderizadas em **1280 × 720 (16:9)**. O gesto, a barra de progresso, o destaque e a recompensa são parte do jogo.

APK publicado: **73767219 bytes**.

```text
SHA-256: 8cc695ebf5ba429138afa7ba52f79bdd1bf5e2d1a56be1ff3bc0c5003dd8ed5b
```

## Teste físico pendente

Não houve acesso a um telefone Android físico. A instalação pelo sistema, a atualização de 1004 para 1005 sem desinstalar e o desempenho/temperatura no Galaxy A56 ainda precisam ser conferidos no aparelho. Os testes no Godot desktop e a verificação do APK não comprovam FPS no telefone.

A mesma identidade de assinatura de teste e o mesmo ID de pacote foram mantidos. Não desinstale a versão anterior se quiser preservar os dados locais ao atualizar.
