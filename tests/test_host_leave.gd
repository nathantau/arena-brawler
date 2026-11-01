extends GutTest
## Leaving a hosted game goes back to the menu, whose LAN browser must be able to listen again.


func test_leaving_as_host_lets_the_menu_browser_listen() -> void:
	var main := Main.new()
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.args.port = 47233
	main._start_host()
	await wait_physics_frames(2)
	main._on_host_leave(false)
	var browser: LanDiscovery = main._menu._browser
	assert_eq(browser.mode, LanDiscovery.Mode.BROWSE, "menu is browsing again")
	assert_not_null(browser._udp, "the browser got the discovery port back (it was still held by the host's announcer)")
