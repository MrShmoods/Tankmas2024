package entities;

import data.types.TankmasDefs.CostumeDef;
import data.types.TankmasDefs.SpriteAnimationDef;
import data.types.TankmasEnums.Costumes;
import data.types.TankmasEnums.PlayerAnimation;
import data.types.TankmasEnums.UnlockCondition;
import entities.NGSprite;

class Player extends NGSprite
{
	var costume:CostumeDef = Costumes.TANKMAN;

	var move_acl:Int = 60;
	var move_speed:Int = 500;

	var move_reverse_mod:Float = 3;

	var shadow:FlxSpriteExt;

	public function new(?X:Float, ?Y:Float)
	{
		super(X, Y);

		sprite_anim.anim(PlayerAnimation.MOVING);

		PlayState.self.players.add(this);

		PlayState.self.player_shadows.add(shadow = new FlxSpriteExt(Paths.get("player-shadow.png")));

		maxVelocity.set(move_speed, move_speed);
		loadGraphic(Paths.get('${costume.name}.png'));

		original_size.set(width, height);

		sprite_anim.anim(PlayerAnimation.IDLE);

		drag.set(300, 300);

		sstate(NEUTRAL);

		screenCenter();
	}

	override function updateMotion(elapsed:Float)
	{
		shadow.center_on_bottom(this);
		shadow.offset.x = offset.x;
		shadow.x = shadow.x + (flipX ? -12 : 16);

		super.updateMotion(elapsed);
	}
	
	override function kill()
	{
		PlayState.self.players.remove(this, true);

		super.kill();
	}

	override function update(elapsed:Float)
	{
		fsm();
		super.update(elapsed);
	}

	function fsm()
		switch (cast(state, State))
		{
			case NEUTRAL:
				general_movement();
				detect_presents();
			case JUMPING:
			case EMOTING:
		}

	function general_movement()
	{
		final UP:Bool = Ctrl.up[1];
		final DOWN:Bool = Ctrl.down[1];
		final LEFT:Bool = Ctrl.left[1];
		final RIGHT:Bool = Ctrl.right[1];
		final NO_KEYS:Bool = !UP && !DOWN && !LEFT && !RIGHT;


		if (UP)
			velocity.y -= move_speed / move_acl * (velocity.y > 0 ? 1 : move_reverse_mod);
		else if (DOWN)
			velocity.y += move_speed / move_acl * (velocity.y < 0 ? 1 : move_reverse_mod);

		if (LEFT)
			velocity.x -= move_speed / move_acl * (velocity.x > 0 ? 1 : move_reverse_mod);
		else if (RIGHT)
			velocity.x += move_speed / move_acl * (velocity.x < 0 ? 1 : move_reverse_mod);

		if (!LEFT && !RIGHT)
			velocity.x = velocity.x * .95;
		else
			flipX = RIGHT;
		// flipX = velocity.x > 0;

		if (!UP && !DOWN)
			velocity.y = velocity.y * .95;

		final MOVING:Bool = velocity.x.abs() + velocity.y.abs() > 10;
		final DO_MOVE_ANIMATION:Bool = MOVING && !NO_KEYS;

		switch (sprite_anim.name)
		{
			default:
			case "idle":
				if (DO_MOVE_ANIMATION)
					sprite_anim.anim(PlayerAnimation.MOVING);
			case "moving":
				if (!DO_MOVE_ANIMATION)
					sprite_anim.anim(PlayerAnimation.IDLE);
		}
		/*
				switch (sprite_anim.name){
					default:
				case "idle":
					if (DO_MOVE_ANIMATION)
						sprite_anim.anim(PlayerAnimation.START_STOP, post_start_stop);
				case "moving":
					if (!DO_MOVE_ANIMATION)
						sprite_anim.anim(PlayerAnimation.START_STOP, post_start_stop);
			}
		 */
	}

	function post_start_stop()
	{
		final MOVING:Bool = velocity.x.abs() + velocity.y.abs() > 10;
		sprite_anim.anim(MOVING ? PlayerAnimation.MOVING : PlayerAnimation.IDLE);
	}
	
	function detect_presents()
	{
		var present:Present = Present.find_present_in_detect_range(this);

		Present.un_mark_all_presents();

		if (present == null)
			return;

		present.mark_target(true);
	}
	function move_animation() {}
}

private enum abstract State(String) from String to String
{
	final NEUTRAL;
	final JUMPING;
	final EMOTING;
}
