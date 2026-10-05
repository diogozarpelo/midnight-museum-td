extends Control

const ROWS: int = 3
const COLUMNS: int = 7

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
    instruction.text = "Clique em uma casa livre para colocar uma sentinela."
    instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(instruction)

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

    cell.set_meta("defender", "sentinel")
    cell.text = "Sentinela"
    selection_label.text = "Sentinela colocada na faixa %d, casa %d." % [
        row + 1, column + 1
    ]
