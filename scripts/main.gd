extends Control

const ROWS: int = 3
const COLUMNS: int = 7

var test_enemy: Label
var enemy_progress: float = 0.0
var enemy_health: int = 100
var enemy_attack_cooldown: float = 0.0
const DEFENDER_HEALTH: int = 100
const GARGOYLE_HEALTH: int = 300
const MAGE_DAMAGE: int = 15
const MAGE_ATTACK_INTERVAL: float = 2.5
const SLOW_DURATION: float = 1.5
const SLOW_MULTIPLIER: float = 0.5
var enemy_slow_remaining: float = 0.0
var selected_defender: String = "sentinel"
var defender_group: ButtonGroup = ButtonGroup.new()
const ENEMY_ATTACK_DAMAGE: int = 25
const ENEMY_ATTACK_INTERVAL: float = 1.0
const ATTACK_DAMAGE: int = 25
const ATTACK_INTERVAL: float = 1.5
const ENEMY_CROSSING_SECONDS: float = 20.0


const ENERGY_PICKUP_VALUE: int = 25
const ENERGY_INTERVAL: float = 5.0
const MAX_ENERGY_PICKUPS: int = 3
var energy: int = 150
var energy_label: Label
var energy_pickups: HBoxContainer

var selection_label: Label
var cell_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
    var layout := VBoxContainer.new()
    layout.name = "BoardLayout"
    add_child(layout)
    layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layout.offset_left = 32
    layout.offset_top = 24
    layout.offset_right = -32
    layout.offset_bottom = -24
    layout.add_theme_constant_override("separation", 16)

    var title := get_node("Title") as Label
    title.reparent(layout)
    title.add_theme_font_size_override("font_size", 32)
    title.custom_minimum_size = Vector2(0, 52)

    var instruction := Label.new()
    instruction.text = "Escolha um defensor e clique em uma casa livre."
    instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(instruction)
    layout.add_child(_create_defender_selector())
    layout.add_child(_create_energy_bar())

    var grid := GridContainer.new()
    grid.name = "Board"
    grid.columns = COLUMNS
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    layout.add_child(grid)

    for row in range(ROWS):
        for column in range(COLUMNS):
            var cell := Button.new()
            cell.name = "Cell_%d_%d" % [row, column]
            cell.text = "%d - %d" % [row + 1, column + 1]
            cell.custom_minimum_size = Vector2(64, 72)
            cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
            cell.toggle_mode = true
            cell.button_group = cell_group
            cell.add_theme_stylebox_override(
                "pressed", _selected_style()
            )
            cell.pressed.connect(_on_cell_pressed.bind(row, column))
            grid.add_child(cell)

    selection_label = Label.new()
    selection_label.text = "Nenhuma casa selecionada."
    selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(selection_label)
    _create_test_enemy()
    _start_energy_timer()


func _selected_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.38, 0.28, 0.10, 1.0)
    style.border_color = Color(0.95, 0.80, 0.45, 1.0)
    style.set_border_width_all(3)
    style.set_corner_radius_all(8)
    return style


func _on_cell_pressed(row: int, column: int) -> void:
    var cell := get_node(
        "BoardLayout/Board/Cell_%d_%d" % [row, column]
    ) as Button

    if cell.has_meta("defender"):
        selection_label.text = "Faixa %d | Casa %d ja ocupada." % [
            row + 1, column + 1
        ]
        return

    if _enemy_overlaps_cell(cell):
        selection_label.text = "Nao pode colocar uma unidade sobre o inimigo."
        return

    var cost: int = _defender_cost(selected_defender)
    if energy < cost:
        selection_label.text = "Energia insuficiente: precisa de %d." % cost
        return

    var health: int = DEFENDER_HEALTH
    if selected_defender == "gargoyle":
        health = GARGOYLE_HEALTH

    energy -= cost
    _refresh_energy_label()
    cell.set_meta("defender", selected_defender)
    cell.set_meta("health", health)
    cell.set_meta("attack_cooldown", 0.0)
    var defender_name: String = _defender_name(selected_defender)
    cell.text = "%s\n%d" % [defender_name, health]
    selection_label.text = "%s na faixa %d, casa %d." % [
        defender_name, row + 1, column + 1
    ]


func _create_test_enemy() -> void:
    test_enemy = Label.new()
    test_enemy.name = "TestEnemy"
    test_enemy.text = "SOMBRA %d" % enemy_health
    test_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    test_enemy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    test_enemy.mouse_filter = Control.MOUSE_FILTER_IGNORE
    test_enemy.add_theme_font_size_override("font_size", 20)
    test_enemy.add_theme_color_override(
        "font_color", Color(1.0, 0.4, 0.5, 1.0)
    )
    test_enemy.add_theme_color_override("font_outline_color", Color.BLACK)
    test_enemy.add_theme_constant_override("outline_size", 6)
    test_enemy.size = Vector2(110, 44)
    test_enemy.visible = false
    add_child(test_enemy)


func _process(delta: float) -> void:
    if not is_instance_valid(test_enemy):
        return

    var first_cell := get_node("BoardLayout/Board/Cell_1_0") as Button
    var last_cell := get_node("BoardLayout/Board/Cell_1_6") as Button

    if first_cell.size.x <= 0.0 or last_cell.position.x <= first_cell.position.x:
        return

    _advance_enemy(delta, first_cell, last_cell)
    var start_x: float = last_cell.global_position.x + last_cell.size.x
    var end_x: float = first_cell.global_position.x
    var center_y: float = first_cell.global_position.y + first_cell.size.y * 0.5

    test_enemy.global_position = Vector2(
        lerpf(start_x, end_x, minf(enemy_progress, 1.0)) - test_enemy.size.x * 0.5,
        center_y - test_enemy.size.y * 0.5
    )
    test_enemy.visible = true

    _update_attacks(delta)
    if enemy_health <= 0:
        return

    var enemy_color := Color(1.0, 0.4, 0.5, 1.0)
    if enemy_slow_remaining > 0.0:
        enemy_color = Color(0.35, 0.75, 1.0, 1.0)
    test_enemy.add_theme_color_override("font_color", enemy_color)

    if enemy_progress >= 1.0:
        selection_label.text = "A sombra chegou a base! Movimento de teste concluido."
        test_enemy.queue_free()
        set_process(false)


func _update_attacks(delta: float) -> void:
    var enemy_center: Vector2 = test_enemy.global_position + test_enemy.size * 0.5

    for column in range(COLUMNS):
        var cell := get_node(
            "BoardLayout/Board/Cell_1_%d" % column
        ) as Button

        if not cell.has_meta("defender"):
            continue

        var defender_id: String = str(cell.get_meta("defender"))
        if defender_id == "gargoyle":
            continue

        var cooldown: float = maxf(
            float(cell.get_meta("attack_cooldown", 0.0)) - delta, 0.0
        )
        cell.set_meta("attack_cooldown", cooldown)

        var cell_center: Vector2 = cell.global_position + cell.size * 0.5
        if cooldown > 0.0 or enemy_center.x <= cell_center.x:
            continue

        var damage: int = ATTACK_DAMAGE
        var interval: float = ATTACK_INTERVAL
        var shot_color := Color(1.0, 0.85, 0.35, 1.0)

        if defender_id == "mage":
            damage = MAGE_DAMAGE
            interval = MAGE_ATTACK_INTERVAL
            shot_color = Color(0.35, 0.75, 1.0, 1.0)
            enemy_slow_remaining = SLOW_DURATION

        cell.set_meta("attack_cooldown", interval)
        _show_shot(cell_center, enemy_center, shot_color)
        enemy_health = maxi(enemy_health - damage, 0)
        test_enemy.text = "SOMBRA %d" % enemy_health

        if enemy_health == 0:
            selection_label.text = "Sombra derrotada!"
            test_enemy.queue_free()
            set_process(false)
            return


func _show_shot(from_position: Vector2, to_position: Vector2, shot_color: Color) -> void:
    var shot := Line2D.new()
    shot.width = 4.0
    shot.default_color = shot_color
    shot.z_index = 10
    add_child(shot)
    shot.add_point(shot.to_local(from_position))
    shot.add_point(shot.to_local(to_position))

    var tween := create_tween()
    tween.tween_property(shot, "modulate:a", 0.0, 0.2)
    tween.tween_callback(shot.queue_free)


func _enemy_overlaps_cell(cell: Button) -> bool:
    if not is_instance_valid(test_enemy):
        return false
    if test_enemy.is_queued_for_deletion() or not test_enemy.visible:
        return false
    return cell.get_global_rect().intersects(test_enemy.get_global_rect())


func _advance_enemy(delta: float, first_cell: Button, last_cell: Button) -> void:
    var start_x: float = last_cell.global_position.x + last_cell.size.x
    var end_x: float = first_cell.global_position.x
    var current_x: float = lerpf(start_x, end_x, enemy_progress)
    var slowed_time: float = minf(delta, enemy_slow_remaining)
    var movement_time: float = delta - slowed_time + slowed_time * SLOW_MULTIPLIER
    enemy_slow_remaining = maxf(enemy_slow_remaining - delta, 0.0)

    var next_progress: float = minf(
        enemy_progress + movement_time / ENEMY_CROSSING_SECONDS, 1.0
    )
    var next_x: float = lerpf(start_x, end_x, next_progress)

    # Examina primeiro as unidades mais proximas da entrada.
    for column in range(COLUMNS - 1, -1, -1):
        var cell := get_node(
            "BoardLayout/Board/Cell_1_%d" % column
        ) as Button

        if not cell.has_meta("defender"):
            continue

        var contact_x: float = cell.global_position.x + cell.size.x * 0.85

        # Detecta contato mesmo quando o movimento cruza o ponto neste frame.
        if current_x >= contact_x - 0.1 and next_x <= contact_x:
            enemy_progress = clampf(
                (start_x - contact_x) / (start_x - end_x), 0.0, 1.0
            )
            enemy_attack_cooldown = maxf(enemy_attack_cooldown - delta, 0.0)

            if enemy_attack_cooldown <= 0.0:
                enemy_attack_cooldown = ENEMY_ATTACK_INTERVAL
                _damage_defender(cell, column)
            return

    enemy_progress = next_progress
    enemy_attack_cooldown = 0.0


func _damage_defender(cell: Button, column: int) -> void:
    var health: int = maxi(
        int(cell.get_meta("health")) - ENEMY_ATTACK_DAMAGE, 0
    )
    cell.set_meta("health", health)
    var defender_name: String = _defender_name(str(cell.get_meta("defender")))
    cell.text = "%s\n%d" % [defender_name, health]

    if health == 0:
        cell.remove_meta("defender")
        cell.remove_meta("health")
        cell.remove_meta("attack_cooldown")
        cell.text = "2 - %d" % [column + 1]
        selection_label.text = "%s foi destruida! A sombra voltou a avancar." % defender_name
    else:
        selection_label.text = "A sombra esta atacando: %s." % defender_name


func _create_defender_selector() -> HBoxContainer:
    var selector := HBoxContainer.new()
    selector.name = "DefenderSelector"
    selector.alignment = BoxContainer.ALIGNMENT_CENTER
    selector.add_theme_constant_override("separation", 12)

    for defender_id in ["sentinel", "gargoyle", "mage"]:
        var button := Button.new()
        button.text = "%s (%d)" % [
            _defender_name(defender_id), _defender_cost(defender_id)
        ]
        button.custom_minimum_size = Vector2(150, 44)
        button.toggle_mode = true
        button.button_group = defender_group
        button.button_pressed = defender_id == selected_defender
        button.pressed.connect(_select_defender.bind(defender_id))
        selector.add_child(button)

    return selector


func _select_defender(defender_id: String) -> void:
    selected_defender = defender_id
    selection_label.text = "Selecionado: %s. Escolha uma casa livre." % [
        _defender_name(defender_id)
    ]


func _defender_name(defender_id: String) -> String:
    if defender_id == "gargoyle":
        return "Gargula"
    if defender_id == "mage":
        return "Mago"
    return "Sentinela"


func _defender_cost(defender_id: String) -> int:
    if defender_id == "mage":
        return 75
    return 50


func _create_energy_bar() -> HBoxContainer:
    var bar := HBoxContainer.new()
    bar.name = "EnergyBar"
    bar.custom_minimum_size = Vector2(0, 44)
    bar.alignment = BoxContainer.ALIGNMENT_CENTER
    bar.add_theme_constant_override("separation", 16)

    energy_label = Label.new()
    energy_label.custom_minimum_size = Vector2(150, 0)
    bar.add_child(energy_label)
    _refresh_energy_label()

    energy_pickups = HBoxContainer.new()
    energy_pickups.name = "Pickups"
    energy_pickups.add_theme_constant_override("separation", 8)
    bar.add_child(energy_pickups)
    return bar


func _refresh_energy_label() -> void:
    energy_label.text = "Energia: %d" % energy


func _start_energy_timer() -> void:
    var timer := Timer.new()
    timer.name = "EnergyTimer"
    timer.wait_time = ENERGY_INTERVAL
    timer.timeout.connect(_spawn_energy_pickup)
    add_child(timer)
    timer.start()


func _spawn_energy_pickup() -> void:
    if energy_pickups.get_child_count() >= MAX_ENERGY_PICKUPS:
        return

    var pickup := Button.new()
    pickup.text = "+%d energia" % ENERGY_PICKUP_VALUE
    pickup.custom_minimum_size = Vector2(110, 44)
    pickup.pressed.connect(_collect_energy.bind(pickup))
    energy_pickups.add_child(pickup)


func _collect_energy(pickup: Button) -> void:
    if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
        return
    if pickup.disabled:
        return

    pickup.disabled = true
    energy += ENERGY_PICKUP_VALUE
    _refresh_energy_label()
    pickup.queue_free()
