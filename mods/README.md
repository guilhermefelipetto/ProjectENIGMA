# Project ENIGMA — Mods

Mods mudam o jogo sem mexer nos arquivos dele: adicionam conversas, golpes, produtos, mudam textos
ou rodam código em momentos do dia. Com nenhum mod ativo, o jogo lê exatamente os mesmos dados de
sempre.

## Para jogar

1. No menu principal, toque em **MODS** (canto superior direito).
2. Ligue os mods que quiser e toque em **Aplicar**.
3. Comece ou continue um jogo: os mods valem a partir do próximo dia iniciado.

Mods que vêm com o jogo ficam em `res://mods/available/`. Mods instalados por você ficam em
`user://mods/` (o botão **Pasta** abre ela):

| Como o jogo roda | Pasta |
|---|---|
| Godot pelo Flatpak | `~/.var/app/org.godotengine.Godot/data/godot/app_userdata/Project ENIGMA/mods/` |
| Linux | `~/.local/share/godot/app_userdata/Project ENIGMA/mods/` |
| Windows | `%APPDATA%\Godot\app_userdata\Project ENIGMA\mods\` |

## Mods incluídos

| Mod | O que faz | Como |
|---|---|---|
| Exemplo Básico | Contato ModsBot no dia 1 e log a cada dia | dados + script (modelo para copiar) |
| Presidente do Brasil te pede PIX | Golpe do falso presidente no dia 2, denunciável | dados |
| Notificações Simultâneas do Caos | 4 contatos te escrevendo ao mesmo tempo no dia 2 | script + `roteiro.json` |
| Tia do WhatsApp™ | Correntes gigantes nos dias 1, 3 e 5 | script + `roteiro.json` |
| Amazônia: Catálogo Estendido™ | 26 produtos absurdos em 3 lojas | dados |
| Códigos Bancários Longos | Todo código Pix/boleto com 120 caracteres | script |
| Cálculo II™ — Pagamentos | Todo `R$` do jogo (textos, Banco, lojas) vira uma conta gerada | script + filtro |
| Modo Idoso | Interface gigante durante o jogo, metade dos botões fora da tela | script |
| Celular de Cabeça para Baixo | O celular inteiro de ponta-cabeça (os toques funcionam) | script |
| Vírus Minerador de Bitcoin | Cada vírus derruba o FPS e "minera" bitcoin | script |
| Frases Impossíveis | Trava-línguas no minigame de digitação | script + `frases.json` |
| Botão Fugitivo | Confirmar/Continuar fogem algumas vezes do clique | script |
| Centavos Invisíveis | Valores ganham um centavo a cada vez que reaparecem | filtro |
| Kwanzas Sem Avisar | Do dia 3 em diante as lojas cobram em kwanzas escritos como R$ | script |

## Criando um mod

Copie `available/exemplo_basico/` para `user://mods/meu_mod/` (ou para `available/`, se for
distribuir com o jogo) e edite.

```
meu_mod/
├── mod.json     # obrigatório
├── data/        # espelha res://data: o que estiver aqui é mesclado nos dados do jogo
└── main.gd      # opcional: código com hooks
```

### `mod.json`

```json
{
	"id": "seunome.meu_mod",
	"name": "Meu Mod",
	"version": "1.0.0",
	"authors": ["Seu Nome"],
	"description": "Aparece na tela MODS.",
	"priority": 0,
	"depends": [],
	"main_script": "main.gd",
	"replace": [],
	"config": {}
}
```

| Campo | Para quê |
|---|---|
| `id` | Único e obrigatório. Use `autor.nome`. |
| `priority` | Mods são aplicados do menor para o maior: o de maior prioridade tem a última palavra. |
| `depends` | `id`s que precisam estar ativos. São sempre aplicados antes deste. |
| `main_script` | Script com `extends Node`, ver abaixo. |
| `replace` | Arquivos que o mod substitui inteiros em vez de mesclar, ex.: `["data/news.json"]`. |
| `config` | Valores livres, lidos no script com `api.config("chave", padrão)`. |
| `pack` | Um `.pck` que sobrescreve arquivos do jogo (cenas, scripts). Último recurso. |

### A pasta `data/`

Ela espelha `res://data`. Cada arquivo é tratado assim:

- **Arquivo novo** (que o jogo não tem): entra como se fosse do jogo. É assim que se adiciona uma
  conversa: `data/messages/<contato>/<arquivo>.json`, ou um evento aleatório:
  `data/random/day_3/scams/<arquivo>.json`.
- **Arquivo que o jogo já tem**: o do mod é **mesclado** por cima:
  - objetos se combinam chave a chave (um evento novo em `data/events/events.json`, um código novo
    em `data/bank/pix_codes_data.json`);
  - listas de objetos com `"id"` se combinam por `id` (mesmo `id` altera, `id` novo adiciona),
    como os produtos de `data/browser/shops_items.json` e as regras de `data/rules/rules.json`;
  - outras listas são concatenadas; o resto é substituído.

O formato de cada arquivo é o do jogo; o jeito mais rápido de aprender é copiar um arquivo parecido
de `res://data`. O mod `presidente_golpista` é um exemplo completo de golpe: conversa com
`entry_points` + `event_id`, código Pix em `data/bank/` e evento com `discrepancies` em
`data/events/`, para o jogador poder denunciar.

> Conversas com `entry_points` entram na fila da história: enquanto o contato fala ou espera
> resposta, os outros esperam (até 60 min do jogo). Para mensagens que não devem segurar ninguém,
> crie a conversa sem `entry_points` e envie pelo script com `api.schedule_messages()`.

### Interface

`ModUI` monta peças com a cara do jogo, por código: `ModUI.dialog(tela)` (fundo escuro com um
cartão no meio, devolve a coluna do cartão), `ModUI.close(coluna)`, `label`, `title`, `button`,
`progress`, `card_panel`. A fonte do jogo não tem emoji nem símbolos como ⚠ ★ ⚡: use texto ou
✓ × → • … ₿.

### `main.gd`

```gdscript
extends Node

var api: ModAPI

func _on_mod_load(mod_api: ModAPI) -> void:
	api = mod_api
	api.hook("day_started", func(story): api.info("dia %d" % GameData.current_day))
	api.schedule_messages(2, 30, "minha_conversa", ["oi", "tudo bem?"])
	api.patch_story_text(func(text: String) -> String: return text.to_upper())
```

| `ModAPI` | |
|---|---|
| `hook(nome, callable)` | `"day_started"` `(story)` depois que os dados do dia são montados; `"clock_tick"` `(minutos, story)` a cada minuto do relógio; `"screen_opened"` `(app, tela)` sempre que uma tela do celular abre (`app` é um `GameData.App`). |
| `watch_nodes(condição, callable)` | Roda o `callable(nó)` para cada nó do jogo que passe na `condição(nó)`, os que já existem e os que vierem. |
| `intercept_press(botão, portão)` | Segura um botão do jogo: ao tocar, roda `portão(prosseguir)` antes; o jogo só faz o que o botão faz se o portão chamar `prosseguir()`. Vários mods podem segurar o mesmo botão. |
| `filter(nome, callable)` | Muda algo que o jogo vai mostrar. `"money_text"` `(texto, valor)`: todo valor em reais escrito pelo jogo enquanto roda (`GameData.format_brl()`: Banco, saldo, lojas, carrinho, boletos). Retorna o texto a mostrar. |
| `wrap_labels(callable)` | Todo `Label` do jogo cujo texto passe no `callable(texto) -> bool` passa a quebrar linha em vez de vazar ou ser cortado. Para mods que escrevem textos maiores do que a tela esperava. |
| `connect_signal(sinal, callable)` | Conecta num sinal do jogo; é desconectado quando o mod é desligado. |
| `patch_json(padrão, callable)` | Muda um JSON do jogo sempre que é lido, depois da mescla. `padrão` aceita `*` (`"res://data/emails/*"`). O callable recebe `(dados, caminho)` e altera no lugar ou retorna um novo valor. |
| `patch_story_text(callable)` | Reescreve todo texto de mensagens, respostas e emails. |
| `send_messages(story, conversa, textos, digitando := true)` | Um contato manda mensagens agora, por fora da fila da história. |
| `schedule_messages(dia, minutos, conversa, textos, digitando := true)` | O mesmo, uma vez no dia (`-1` = todo dia) aos `minutos` depois das 08:00. |
| `read_json(caminho)` | Lê um JSON do jogo como os mods ativos deixam. |
| `read_mod_json(relativo)` / `path(relativo)` | Arquivos do próprio mod. |
| `config(chave, padrão)` | Valor do `config` do `mod.json`. |
| `info(msg)` / `warn(msg)` | Log com o `id` do mod. |

Se um texto é comparado por um evento (`"contains"` nas `discrepancies`), reescreva os dois do
mesmo jeito, senão a denúncia para de funcionar. `calculo_2_pagamentos` e `long_payment_codes`
fazem isso usando `patch_json("res://data/*", …)`.

## Segurança

Scripts de mods em `user://mods/` rodam com acesso total (arquivos, rede, `OS.execute`). Instale só
de quem você confia; o jogo avisa no log quando carrega um.

## Para quem mexe no jogo

- Autoload `ModLoader` (`loader/mod_loader.gd`), registrado antes do `GameData`.
- O jogo lê dados por `ModLoader.read_json()`, `list_json_files()` e `list_subdirectories()`
  (em `story_director.gd`, `game_data.gd`, `notes_board.gd`, `passwords_changer.gd`,
  `order_document.gd` e `day_introduction_ui.gd`). Ao ler um JSON novo de `res://data`, use
  `ModLoader.read_json()` para que os mods o alcancem.
- Hooks: `ModLoader.emit_hook("day_started", [self])` e `"clock_tick"` no `story_director.gd`.
- Filtros: `ModLoader.apply_filter("money_text", texto, [valor])` no fim de `GameData.format_brl()`.
- Teste: `mods/tests/run.sh` (falha também se o Godot logar algum `ERROR` durante o teste)
