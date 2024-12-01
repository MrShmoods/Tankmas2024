package ui.popups;

import data.SaveManager;
import flixel.FlxBasic;
import flixel.addons.display.FlxSpriteAniRot;
import flixel.tweens.FlxEase;
import squid.ext.FlxTypedGroupExt;

class StickerPackOpening extends FlxTypedGroupExt<FlxObject>
{
	var sticker_pack:FlxSpriteExt;

	var sticker_pack_descent_speed:Float = 0.5;
	var sticker_ascent_speed:Float = 0.7;

	var black:FlxSpriteExt;
	var black_alpha:Float = 0.75;

	static final max_hits:Int = 4;

	var initial_idle:Int = 30;
	var post_hit_wait:Int = 5;

	var hits:Int = 0;

	var stickers:Array<FlxSpriteExt> = [];

	var sticker_draw:Array<String> = [];

	var ran:FlxRandom = new FlxRandom();

	var wobble_rate:Int = 3;
	var wobble_amount:Int = 4;

	public function new(sticker_draw:Array<String>)
	{
		super();

		this.sticker_draw = sticker_draw;

		black = new FlxSpriteExt().makeGraphicExt(FlxG.width + 100, FlxG.height + 100, FlxColor.BLACK);
		black.alpha = 0;
		black.screenCenter();

		sticker_pack = new FlxSpriteExt(0, 0).one_line("sticker-pack-opening");

		add(black);
		add(sticker_pack);

		sticker_pack.offset.set(0, -FlxG.height);
		sticker_pack.screenCenter();

		black.tween = FlxTween.tween(black, {alpha: black_alpha}, sticker_pack_descent_speed, {ease: FlxEase.quadInOut});

		sticker_pack.tween = FlxTween.tween(sticker_pack.offset, {y: 0}, sticker_pack_descent_speed, {
			ease: FlxEase.quadInOut,
			onComplete: (t) -> sstate(INITIAL_IDLE)
		});

		sstate(STICKER_PACK_IN);

		SaveManager.save_collections();

		make_stickers();

		for (member in members)
			member.scrollFactor.set(0, 0);
	}

	function make_stickers()
	{
		for (n in 0...3)
		{
			var sticker:FlxSpriteExt = new FlxSpriteExt(Paths.get('${sticker_draw[n]}.png'));
			sticker.screenCenter();

			switch (n)
			{
				case 0:
					sticker.setPosition(sticker.x - 50, sticker.y - 25);
				case 1:
					sticker.setPosition(stickers[0].x + 100, stickers[0].y + 25 + 25);
				case 2:
					sticker.setPosition(stickers[1].x - 75, stickers[1].y + 25 + 25);
			}

			sticker.visible = false;
			stickers.push(sticker);
		}

		for (n in 0...3)
		{
			trace(n, 2 - n);
			add(stickers[2 - n]);
		}
	}

	override function update(elapsed:Float)
	{
		fsm();

		super.update(elapsed);
	}

	function fsm()
		switch (cast(state, State))
		{
			default:
			case INITIAL_IDLE:
				if (ttick() > 30)
					sstate(HIT_IT, fsm);
			case HIT_IT:
				hits++;
				sticker_pack.animProtect('${hits}');
				sstate(HITTING, fsm);
				Utils.shake(ShakePreset.LIGHT);
			case HITTING:
				if (sticker_pack.animation.finished)
					sstate(POST_HIT, fsm);
			case POST_HIT:
				if (ttick() > post_hit_wait)
					sstate(hits == max_hits ? PRE_KABOOM : HIT_IT, fsm);
			case PRE_KABOOM:
				sticker_pack.animProtect("pre-kaboom");
				if (sticker_pack.animation.finished)
				{
					Utils.shake(ShakePreset.DAMAGE);
					FlxG.camera.flash(() -> sstate(STICKERS_OUT));
					sticker_pack.kill();
					for (sticker in stickers)
						sticker.visible = true;
					sstate(KABOOM, fsm);
				}
			case KABOOM:
				if (ttick() % wobble_rate == 0)
					sticker_wobble();
			case STICKERS_OUT:
				ttick();
				if (tick % wobble_rate == 0)
					sticker_wobble();
				for (n in 0...3)
					if (tick == n * 15 + 1)
					{
						var sticker:FlxSpriteExt = stickers[n];
						sticker.tween = FlxTween.tween(sticker, {y: -sticker.height}, sticker_ascent_speed, {
							ease: FlxEase.elasticIn
						});
						if (n == 2)
							sticker.tween.onComplete = (t) -> sstate(FADE_OUT, fsm);
					}
			case FADE_OUT:
				Ctrl.mode = ControlModes.OVERWORLD;
				sstate(WAIT);
				black.tween = FlxTween.tween(black, {alpha: 0}, sticker_pack_descent_speed, {ease: FlxEase.elasticInOut, onComplete: (t) -> kill});
		}

	override function kill()
	{
		super.kill();
	}

	function sticker_wobble()
	{
		for (sticker in stickers)
		{
			var old_offset:FlxPoint = sticker.offset.copyTo(FlxPoint.weak());
			while (sticker.offset.x == old_offset.x && sticker.offset.y == old_offset.y)
				sticker.offset.set(ran.getObject([-1, 0, 1]) * wobble_amount, ran.getObject([-1, 0, 1]) * wobble_amount);
		}
	}
}

private enum abstract State(String) from String to String
{
	final STICKER_PACK_IN;
	final INITIAL_IDLE;
	final HIT_IT;
	final HITTING;
	final POST_HIT;
	final PRE_KABOOM;
	final KABOOM;
	final STICKERS_OUT;
	final FADE_OUT;
	final WAIT;
}