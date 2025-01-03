package net.tankmas;

import levels.TankmasLevel.RoomId;
import data.JsonData;
import data.SaveManager;
import data.types.TankmasDefs.CostumeDef;
import entities.NetUser;
import entities.Player;
import entities.base.BaseUser;
import net.tankmas.NetDefs;
import net.tankmas.TankmasClient;

/**
 * The main game online update loop, yea!
 */
class OnlineLoopHttp
{
	static final host_uri:String =
		#if host_address
		'${haxe.macro.Compiler.getDefine("host_address")}'
		#elseif test_local
		'127.0.0.1:5000'
		#elseif dev
		"test.tankmas-adventure.com"
		#else
		"tankmas.kornesjo.se:25567"
		#end;

	static final use_tls:Bool =
		#if use_tls
		true
		#elseif (test_local || host_address)
		false
		#else
		true
		#end;

	public static final http_address = '${use_tls ? 'https://' : 'http://'}${host_uri}';
	public static final ws_address = '${use_tls ? 'wss://' : 'ws://'}${host_uri}';

	public static var rooms_post_tick_rate:Float = 0;
	public static var rooms_get_tick_rate:Float = 0;
	public static var events_get_tick_rate:Float = 0;

	public static var emote_tick_limit:Int = 1000;

	// base server tick rate is 200 rn
	public static var rooms_post_tick_rate_multiplier:Float = 1;
	public static var rooms_get_tick_rate_multiplier:Float = 5;
	public static var events_get_tick_rate_multiplier:Float = 5;

	static var last_rooms_post_timestamp:Float;
	static var last_rooms_get_timestamp:Float;
	static var last_events_get_timestamp:Float;

	static var last_websocket_player_tick_timestamp:Float;
	static final websocket_state_send_interval = 0.5;

	static var last_room_id:Null<RoomId> = null;

	static final tick_wait_timeout:Int = -1;

	public static var current_timestamp(get, default):Float;

	public static var force_send_full_user:Bool;

	static var websocket:WebsocketClient;

	static function get_current_timestamp():Float
		return haxe.Timer.stamp();

	/**
	 * Runs once at game startup
	 */
	public static function init()
	{
		#if offline return; #end
		#if legacy_server
		#if (dev && test_local)
		Main.session_id = 'test_session';
		#end

		if (websocket == null)
		{
			trace('initing online loop');
			websocket = new WebsocketClient();
		}

		websocket.connect();

		force_send_full_user = true;

		rooms_post_tick_rate = 0;
		rooms_get_tick_rate = 0;
		events_get_tick_rate = 0;

		last_rooms_post_timestamp = current_timestamp;
		last_rooms_get_timestamp = current_timestamp;
		last_events_get_timestamp = current_timestamp;

		last_websocket_player_tick_timestamp = current_timestamp;
		#end
	}

	public static function iterate(elapsed:Float = 0.0)
	{
		#if (legacy_server && !offline)
		if (websocket != null)
			websocket.update(elapsed);

		if (Main.current_room_id != last_room_id)
		{
			force_send_full_user = true;
			last_room_id = Main.current_room_id;
		}

		// If playstate is not active, or lacks player, we're not yet online.
		if (PlayState.self == null || PlayState.self.player == null)
			return;

		var tick_diff = current_timestamp - last_websocket_player_tick_timestamp;
		if (!force_send_full_user && tick_diff < websocket_state_send_interval)
			return;

		last_websocket_player_tick_timestamp = current_timestamp;

		send_player_state(force_send_full_user);
		force_send_full_user = false;
		#end
	}

	public static function send_player_state(do_full_update:Bool = false)
	{
		#if legacy_server
		if (PlayState.self == null)
			return;
		var json:NetUserDef = PlayState.self.player.get_user_update_json(do_full_update);
		if (json.x != null || json.y != null || json.costume != null || json.sx != null)
		{
			#if !websocket
			TankmasClient.post_user(room_id, json, after_post_player);
			#else
			websocket.send_player(json);
			#end
		}
		#end
	}

	/**This is a post request**/
	public static function post_sticker(sticker_name:String)
	{
		post_event({type: STICKER, data: {"name": sticker_name}});
	}

	public static function post_marshmallow_discard(marshmallow_level:Int)
	{
		post_event({type: DROP_MARSHMALLOW, data: {"level": marshmallow_level}});
	}

	/**This is a post request**/
	public static function post_event(event:NetEventDef)
	{
		#if legacy_server
		#if offline return #end

		#if !websocket
		TankmasClient.post_event(Main.current_room_id, event);
		#else
		websocket.send_event(event.type, event.data);
		#end
		#end
	}

	/**This is a get request**/
	public static function get_room(room_id:Int)
	{
		#if legacy_server
		rooms_get_tick_rate = tick_wait_timeout;
		TankmasClient.get_users_in_room(room_id, update_user_visuals);
		#end
	}

	/**This is a post request**/
	public static function get_events(room_id:Int)
	{
		#if legacy_server
		events_get_tick_rate = tick_wait_timeout;
		TankmasClient.get_events(room_id, update_user_events);
		#end
	}

	public static function after_post_player(data:Dynamic)
	{
		#if legacy_server
		rooms_post_tick_rate = data.tick_rate * rooms_post_tick_rate_multiplier;
		if (data.request_for_more_info)
		{
			force_send_full_user = true;
			data.tick_rate = 0;
		}
		#end
	}

	public static function update_user_visual(username:String, def:NetUserDef)
	{
		#if legacy_server
		if (PlayState.self == null)
			return;

		#if !ghosttown
		var is_local_player = username == Main.username;

		if (is_local_player && !def.immediate)
			return;

		var costume:CostumeDef = JsonData.get_costume(def.costume);

		var create_function = () ->
		{
			return new NetUser(def.x, def.y, username, costume);
		}

		var user:BaseUser = BaseUser.get_user(username, !is_local_player ? create_function : null);

		if (user == null)
			return;

		var new_x = def.x != null ? def.x : user.x;
		var new_y = def.y != null ? def.y : user.y;
		var new_sx = def.sx;

		if (!def.immediate)
		{
			cast(user, NetUser).move_to(new_x, new_y, new_sx);
		}
		else
		{
			user.x = new_x;
			user.y = new_y;
		}

		if (costume != null && (user.costume == null || user.costume.name != costume.name))
			user.new_costume(costume);
		#end
		#end
	}

	public static function update_user_visuals(data:Dynamic)
	{
		#if legacy_server
		#if !ghost_town
		if (PlayState.self == null)
		{
			return;
		}

		var usernames:Array<String> = Reflect.fields(data.data);

		usernames.remove(Main.username);

		for (username in usernames)
		{
			if (username.contains("temporary_random_username"))
				continue;
			var def:NetUserDef = Reflect.field(data.data, username);
			update_user_visual(username, def);
		}

		rooms_get_tick_rate = data.tick_rate * rooms_get_tick_rate_multiplier;
		rooms_post_tick_rate = data.tick_rate * rooms_post_tick_rate_multiplier;

		events_get_tick_rate = data.tick_rate * events_get_tick_rate_multiplier;
		#end
		#end
	}

	public static function update_user_events(data:Dynamic)
	{
		#if legacy_server
		#if !ghost_town
		var events:Array<NetEventDef> = data.data.events;

		for (event in events)
		{
			var user = BaseUser.get_user(event.username);
			if (user != null)
				user.on_event(event);
		}
		rooms_get_tick_rate = data.tick_rate * rooms_get_tick_rate_multiplier;
		#end
		#end
	}
}
