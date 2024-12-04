package states;

import ui.popups.ServerNotificationMessagePopup;
import activities.ActivityArea;
import data.SaveManager;
import entities.Interactable;
import entities.Minigame;
import entities.NPC;
import entities.Player;
import entities.Present;
import entities.base.BaseUser;
import entities.base.NGSprite;
import flixel.tile.FlxTilemap;
import fx.StickerFX;
import fx.Thumbnail;
import levels.TankmasLevel;
import minigames.MinigameHandler;
import net.tankmas.NetDefs.NetEventDef;
import net.tankmas.NetDefs.NetEventType;
import net.tankmas.NetDefs.NetUserDef;
import net.tankmas.OnlineLoop;
import net.tankmas.TankmasClient;
import ui.DialogueBox;
import ui.MainGameOverlay;
import ui.TouchOverlay;
import ui.popups.StickerPackOpening;
import ui.sheets.*;
import ui.sheets.SheetMenu;
import video.PremiereHandler;
import zones.Door;

class PlayState extends BaseState
{
	public static var self:PlayState;

	static final default_world:String = "outside_hotel";

	public var current_room_id = 1;

	var current_world:String;

	public var player:Player;
	public var users:FlxTypedGroup<BaseUser> = new FlxTypedGroup<BaseUser>();
	public var username_tags:FlxTypedGroup<FlxText> = new FlxTypedGroup<FlxText>();
	public var presents:FlxTypedGroup<Present> = new FlxTypedGroup<Present>();
	public var objects:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
	public var thumbnails:FlxTypedGroup<Thumbnail> = new FlxTypedGroup<Thumbnail>();
	public var shadows:FlxTypedGroup<FlxSpriteExt> = new FlxTypedGroup<FlxSpriteExt>();
	public var stickers:FlxTypedGroup<StickerFX> = new FlxTypedGroup<StickerFX>();
	public var sticker_fx:FlxTypedGroup<NGSprite> = new FlxTypedGroup<NGSprite>();
	public var dialogues:FlxTypedGroup<DialogueBox> = new FlxTypedGroup<DialogueBox>();
	public var npcs:FlxTypedGroup<NPC> = new FlxTypedGroup<NPC>();
	public var minigames:FlxTypedGroup<Minigame> = new FlxTypedGroup<Minigame>();
	public var misc_sprites:FlxTypedGroup<FlxSpriteExt> = new FlxTypedGroup<FlxSpriteExt>();

	public var levels:FlxTypedGroup<TankmasLevel> = new FlxTypedGroup<TankmasLevel>();
	public var level_backgrounds:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();
	public var level_collision:FlxTypedGroup<FlxTilemap> = new FlxTypedGroup<FlxTilemap>();

	/**Do not add to state*/
	public var interactables:FlxTypedGroup<Interactable> = new FlxTypedGroup<Interactable>();

	public var activity_areas:FlxTypedGroup<ActivityArea> = new FlxTypedGroup();

	public var doors:FlxTypedGroup<Door> = new FlxTypedGroup<Door>();

	public var ui_overlay:MainGameOverlay;

	public var sheet_menu:SheetMenu;

	public var touch:TouchOverlay;

	public static var show_usernames(default, set):Bool = true;

	public var premieres:PremiereHandler;

	// No idea how I could get this into the overlay ui
	public var notification_message:ServerNotificationMessagePopup;

	public function new(?world_to_load:String)
	{
		if (world_to_load != null)
			current_world = world_to_load
		else
			current_world = SaveManager.savedRoom == null ? default_world : SaveManager.savedRoom;
		super();
	}

	override public function create()
	{
		super.create();

		Ctrl.mode = ControlModes.OVERWORLD;

		self = this;

		OnlineLoop.init();

		SaveManager.load(on_save_loaded, () ->
		{
			// Save failed to load, give player control anyway.
			on_save_loaded();
		});

		premieres = new PremiereHandler();

		bgColor = FlxColor.BLACK;

		make_world();
		make_ui();

		add(level_backgrounds);
		add(levels);
		add(level_collision);

		add(touch = new TouchOverlay());

		add(shadows);

		add(misc_sprites);

		add(minigames);
		add(npcs);
		add(username_tags);
		add(users);
		add(presents);
		add(objects);
		add(thumbnails);
		add(stickers);
		add(sticker_fx);
		add(dialogues);

		add(doors);

		add(ui_overlay);

		notification_message = new ServerNotificationMessagePopup();
		add(notification_message);

		// add(new DialogueBox(Lists.npcs.get("thomas").get_state_dlg("default")));

		MinigameHandler.instance.initialize();

		FlxG.autoPause = false;
		FlxG.camera.target = player;

		var bg:FlxObject = level_backgrounds.members[0];

		FlxG.worldBounds.set(bg.x, bg.y, bg.width, bg.height);
		FlxG.camera.setScrollBoundsRect(bg.x, bg.y, bg.width, bg.height);

		#if !show_collision
		level_collision.visible = false;
		#end

		SaveManager.load_costumes();
		SaveManager.load_emotes();

		// FlxG.camera.setScrollBounds(bg.x, bg.width, bg.y, bg.height);

		OnlineLoop.iterate();

		// runs nearby animation if not checked here
		for (mem in presents.members)
			mem.checkOpen();

		SaveManager.save_room();
	}

	function on_save_loaded()
	{
		player.on_save_loaded();
	}

	override public function update(elapsed:Float)
	{
		OnlineLoop.iterate(elapsed);

		premieres.update(elapsed);

		super.update(elapsed);
		// Ctrl.update();

		#if dev
		if (Ctrl.reset[1] && !FlxG.keys.pressed.SHIFT)
			FlxG.switchState(new PlayState());

		if (Ctrl.reset[1] && FlxG.keys.pressed.SHIFT)
			SaveManager.save();

		if (FlxG.keys.justPressed.N)
			notification_message.show("I'm a test notification message and\n  I just want to say hi :)");
		#end

		if (Ctrl.mode.can_open_menus)
			if (Ctrl.jmenu[1])
				try
				{
					new SheetMenu();
				}
				catch (e)
				{
					trace(e);
				}

		handle_collisions();
	}

	function handle_collisions()
		FlxG.collide(level_collision, player);

	override function destroy()
	{
		self = null;
		super.destroy();
	}

	function make_world()
	{
		final date:Date = Date.now();
		final theNum:Int = Main.get_current_bg(date.getMonth() != 11 ? 32 : date.getDate());
		TankmasLevel.make_all_levels_in_world(current_world);
		for (level in levels)
			level.place_entities();
	}

	public function remove_user(username:String)
	{
		if (username == Main.username)
			return;

		var user:BaseUser = BaseUser.get_user(username);
		if (user != null)
		{
			user.on_user_left();
		}
	}

	function make_ui()
	{
		ui_overlay = new MainGameOverlay();
	}

	public static function set_show_usernames(val:Bool):Bool
	{
		for (username_tag in self.username_tags.members)
			username_tag.visible = val;
		return show_usernames = val;
	}

	// Happens whenever a custom event is received from the server.
	// Currently these include stickers and marshmallow drops
	public function on_net_event_received(event:NetEventDef)
	{
		if (event.room_id != null && event.room_id != current_room_id)
			return;

		// If event has an username, pass it to the user.
		if (event.username != null)
		{
			var user = BaseUser.get_user(event.username);
			if (user != null)
			{
				user.on_event(event);
			}
		}

		// We could also do stuff here, like add a broadcast message type
		// which could show a text on screen for every connected player etc.
		if (event.type == NetEventType.STICKER)
		{
			// Any player postede a sticker.
		}
	}
}
