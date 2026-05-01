# CFS Integration Context

Este arquivo documenta o que foi implementado no OrcaSlicer para integrar a CFS da Creality, quais arquivos foram alterados, como o fluxo funciona e quais foram os pontos delicados durante os testes.

## Objetivo

Adicionar ao OrcaSlicer uma integração com a CFS da Creality para:

- ler automaticamente os materiais da CFS via WebSocket
- sincronizar cor dos filamentos no Orca
- opcionalmente sincronizar preset de filamento no Orca com base no tipo da CFS
- opcionalmente enviar alterações de cor do Orca de volta para a CFS
- opcionalmente enviar alterações de preset do Orca de volta para a CFS
- exibir estado visual simples de ativação da integração

## Base usada como referência

A referência funcional do protocolo foi este projeto:

- `C:\Users\conta\OneDrive\Documentos\Projetos\poc-kisskh\ref\creality-cfs-mainsail-integration\static\mainsail-panel.js`

Ele foi tratado como fonte de verdade para:

- endpoint WebSocket
- heartbeat
- polling
- resposta `ok`
- leitura de `boxsInfo`
- comando `modifyMaterial`
- normalização de cor

## Arquivos alterados

As mudanças principais ficaram nestes arquivos:

- `C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\src\slic3r\GUI\Plater.cpp`
- `C:\Users\conta\OneDrive\Documentos\Projetos\OrcaSlicer\src\slic3r\GUI\Plater.hpp`

Praticamente toda a integração foi concentrada em `Plater.cpp` e `Plater.hpp` para reduzir espalhamento inicial.

## Resumo da arquitetura

### 1. Cliente WebSocket persistente da CFS

Foi criado um runtime próprio em `Plater.cpp` para manter uma sessão persistente com a CFS:

- host derivado de `print_host` / `print_host_webui`
- conexão em `ws://<ip>:9999`
- heartbeat periódico
- polling de `boxsInfo`
- leitura contínua de mensagens
- fila de comandos `modifyMaterial`
- reconexão automática em caso de falha

Constantes relevantes:

- `cfs_socket_timeout`
- `cfs_socket_recent_success_window`
- `cfs_socket_poll_interval_ms`
- `cfs_socket_retry_ms`
- `cfs_socket_heartbeat_ms`
- `cfs_socket_idle_sleep_ms`

### 2. Modelo local dos slots da CFS

O parser de `boxsInfo` não guarda só cor. Ele passou a armazenar metadados por slot, incluindo:

- `color`
- `type`
- `vendor`
- `name`
- `rfid`
- `min_temp`
- `max_temp`
- `pressure`

Isso é importante porque o comando `modifyMaterial` da CFS precisa mandar o material inteiro, não só a cor.

### 3. UI do Orca

Na área de filamentos foram adicionados:

- botão principal `CFS`
- link `Configure CFS`
- badge `CFS` em cada slot de filamento quando o modo automático está ativo

### 4. Configuração persistente

A integração salva preferências no `app_config`:

- `cfs_color_auto_sync`
- `cfs_auto_apply_filament_preset`
- `cfs_preset_map_pla`
- `cfs_preset_map_petg`

## Fluxos implementados

## A. CFS -> Orca: sincronização de cor

Quando a sessão recebe `boxsInfo`:

1. o JSON é parseado
2. os 4 slots são extraídos
3. as cores são normalizadas
4. o Orca reaplica as cores na UI

O caminho que acabou funcionando melhor para refletir visualmente foi usar o fluxo nativo da UI do Orca em vez de só gravar `filament_colour` manualmente.

Funções centrais envolvidas:

- `extract_cfs_materials_from_json(...)`
- `apply_cfs_colors_to_ui(...)`
- `apply_cfs_materials_to_ui(...)`
- `sync_cfs_colors()`

## B. CFS -> Orca: sincronização automática de preset

Quando ativado no `Configure CFS`, o tipo vindo da CFS é mapeado para presets do Orca.

Nesta fase inicial, o foco ficou em dois tipos:

- `PLA`
- `PETG`

O mapeamento é configurável pelo usuário:

- `PLA -> <preset escolhido>`
- `PETG -> <preset escolhido>`

Funções centrais:

- `normalize_cfs_material_type(...)`
- `get_cfs_preset_mapping_for_type(...)`
- `apply_cfs_presets_to_ui(...)`
- `apply_cfs_materials_to_ui(...)`

## C. Orca -> CFS: envio de cor

Quando a cor do filamento muda no Orca:

1. a cor é normalizada para o formato esperado pela CFS
2. o slot correto é identificado
3. é montado um payload `modifyMaterial`
4. o payload entra numa fila
5. a sessão WebSocket persistente envia na próxima iteração

Funções centrais:

- `encode_cfs_printer_color(...)`
- `cfs_build_modify_material_payload(...)`
- `queue_cfs_color_push(...)`
- `cfs_socket_queue_modify_material(...)`

## D. Orca -> CFS: envio de preset

Quando o preset do Orca muda e a opção de aplicar preset automaticamente está ativa:

1. o preset atual é convertido para um tipo da CFS
2. se existir um preset conhecido da base interna, ele é transformado em payload completo
3. esse payload é enviado para a CFS

Aqui foi importada uma base mínima de presets da CFS para evitar mandar só nome solto sem os outros campos:

- `PLA`
- `PETG`

Estrutura relevante:

- `CfsMaterialPresetDefinition`
- `cfs_material_preset_definitions[]`
- `find_cfs_material_preset_definition(...)`
- `queue_cfs_preset_push(...)`
- `get_cfs_material_type_for_preset(...)`

## Protocolo usado

### Heartbeat

Mensagem enviada:

```json
{"ModeCode":"heart_beat"}
```

Quando a CFS responde com mensagem contendo heartbeat, o cliente responde:

```text
ok
```

### Leitura de estado

```json
{"method":"get","params":{"boxsInfo":1}}
```

### Escrita de material

```json
{"method":"set","params":{"modifyMaterial":{...}}}
```

## Regras de cor

Um ponto importante foi seguir a mesma normalização do projeto base.

Funções relevantes:

- `normalize_cfs_color(...)`
- `encode_cfs_printer_color(...)`

Isso foi necessário porque a CFS usa formatos como:

- `#0f4e076`
- `#04b697d`

e eles precisam ser convertidos de forma consistente para não aplicar cor errada.

## Comportamento visual

### Botão superior `CFS`

Estados principais:

- conectado + desativado: cinza
- conectado + ativado: verde
- sem conexão viva: vermelho

O texto do botão foi padronizado para `CFS`.

### Badges dos slots

Quando o modo automático está ativo, cada slot exibe badge `CFS`.

Estados principais:

- conectado: verde
- offline: vermelho

## Configuração da UI

Em vez de deixar controles permanentes poluindo a sidebar, a configuração ficou assim:

- um link `Configure CFS`
- clicando nele, abre uma modal
- dentro da modal:
  - checkbox para aplicar preset automaticamente
  - select para mapeamento de `PLA`
  - select para mapeamento de `PETG`

## Filtro por impressora

A integração não deve aparecer para qualquer impressora.

O filtro atual foi concentrado em:

- `Sidebar::is_cfs_supported_printer()`

Pontos importantes que apareceram nos testes:

- o `printer_type` resolvido nem sempre vinha preenchido
- alguns presets vinham com `printer_model` em formato inesperado
- por isso foi importante registrar logs de:
  - `type`
  - `model`
  - `preset`

Esses logs ajudaram a separar:

- dados do preset selecionado
- dados do perfil de sistema
- dados da impressora em uso

## Pontos delicados encontrados

### 1. Não confiar só no visual

Muitas vezes o botão podia aparecer sem garantir que o fluxo inteiro estava ok. Por isso os logs em `warning` foram fundamentais nos testes.

### 2. Fechamento curto da conexão

O servidor da CFS pode aceitar, responder e depois fechar. Isso exigiu tratar bem:

- reconexão
- estado visual
- diferença entre “conectou agora” e “última leitura bem-sucedida”

### 3. `modifyMaterial` precisa de payload completo

Não basta mandar só cor. Para enviar de volta à CFS, foi necessário manter os metadados do slot em memória.

### 4. Atualização visual do botão

O botão passou por conflitos com `Rescale()` e reaplicação de estilo. Por isso a atualização visual da UI precisou ser consolidada em:

- `update_cfs_auto_sync_ui()`
- `update_cfs_filament_badges()`

### 5. Logs em nível errado

Durante o desenvolvimento, logs importantes em `info` não apareciam no arquivo de release. Por isso vários pontos críticos foram movidos para `warning`.

## Funções principais para manutenção futura

Se alguém continuar esse trabalho depois, estes são os pontos mais importantes para abrir primeiro:

- `Sidebar::is_cfs_supported_printer()`
- `Sidebar::get_cfs_socket_host()`
- `Sidebar::get_cfs_socket_origin()`
- `Sidebar::refresh_cfs_sync_state(...)`
- `Sidebar::sync_cfs_colors()`
- `Sidebar::handle_cfs_auto_sync_tick()`
- `Sidebar::apply_cfs_materials_to_ui(...)`
- `Sidebar::apply_cfs_presets_to_ui(...)`
- `Sidebar::apply_cfs_colors_to_ui(...)`
- `Sidebar::queue_cfs_color_push(...)`
- `Sidebar::queue_cfs_preset_push(...)`
- `Sidebar::update_cfs_auto_sync_ui()`
- `Sidebar::update_cfs_filament_badges()`
- `Sidebar::open_cfs_config_dialog()`
- `run_cfs_socket_session(...)`

## Estado funcional alcançado

Na fase atual, os fluxos principais testados/implementados ficaram:

- leitura de materiais da CFS
- sync manual de cor
- sync automático de cor
- toggle visual `CFS`
- badges `CFS` por slot
- configuração de mapeamento PLA/PETG
- troca automática de preset no Orca com base no tipo da CFS
- envio de cor do Orca para a CFS
- envio de preset do Orca para a CFS

## Sugestões de próximos passos

Se continuar essa integração no futuro, os próximos passos naturais são:

- ampliar a base de presets da CFS além de `PLA` e `PETG`
- mover parte da lógica de CFS para arquivo/classe própria para reduzir peso em `Plater.cpp`
- separar melhor “impressora suportada” de “host configurado”
- revisar se o filtro por impressora deve usar:
  - preset selecionado
  - máquina conectada
  - ou ambos
- adicionar testes/guias de regressão para:
  - troca de preset
  - troca de cor
  - reconexão
  - estado offline

## Arquivo de referência mais importante

Se alguém precisar revalidar o protocolo original, o arquivo mais importante é:

- `C:\Users\conta\OneDrive\Documentos\Projetos\poc-kisskh\ref\creality-cfs-mainsail-integration\static\mainsail-panel.js`

Esse arquivo continua sendo a melhor referência prática para confirmar o comportamento esperado do socket da CFS.
