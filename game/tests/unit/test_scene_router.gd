extends GdUnitTestSuite

const SceneRouterScript: GDScript = preload("res://autoload/scene_router.gd")


func test_back_without_history_returns_false() -> void:
	var router: CanvasLayer = auto_free(SceneRouterScript.new())
	assert_bool(router.go_back()).is_false()
	assert_int(router.history_size()).is_equal(0)
