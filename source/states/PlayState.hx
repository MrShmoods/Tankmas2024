package states;

import entities.Player;
import entities.Present;
import entities.base.BaseUser;
import flixel.FlxState;
import flixel.text.FlxText;
import net.tankmas.OnlineLoop;
import net.tankmas.TankmasClient;
import ui.sheets.CostumeSelectSheet;


class PlayState extends BaseState
{
	public static var self:PlayState;

	var bg:FlxSpriteExt;

	public var player:Player;
	public var users:FlxTypedGroup<BaseUser> = new FlxTypedGroup<BaseUser>();
	public var presents:FlxTypedGroup<Present> = new FlxTypedGroup<Present>();
	public var shadows:FlxTypedGroup<FlxSpriteExt> = new FlxTypedGroup<FlxSpriteExt>();

	override public function create()
	{
		super.create();
		self = this;

		OnlineLoop.init();
		
		bgColor = FlxColor.GRAY;

		add(bg = new FlxSpriteExt(Paths.get("bg-outside-hotel.png")));

		add(shadows);
		add(presents);
		add(users);

		new Player();
		
		player.center_on(bg);

		new Present();

		FlxG.camera.target = player;

		FlxG.camera.setScrollBounds(bg.x, bg.width, bg.y, bg.height);
		OnlineLoop.iterate();
	}

	override public function update(elapsed:Float)
	{
		OnlineLoop.iterate();

		super.update(elapsed);

		if (FlxG.keys.anyJustPressed(["R"]))
			FlxG.switchState(new PlayState());
		if (FlxG.keys.anyJustPressed(["C"]))
			new CostumeSelectSheet();
	}

	override function destroy()
	{
		self = null;
		super.destroy();
	}
}
