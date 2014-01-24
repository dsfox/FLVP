package {

  import flash.display.Sprite;
  import flash.display.StageAlign;
  import flash.display.StageDisplayState;
  import flash.events.Event;
  import flash.events.NetStatusEvent;
  import flash.external.ExternalInterface;
  import flash.media.SoundTransform;
  import flash.media.Video;
  import flash.net.NetConnection;
  import flash.net.NetStream;

  //set swf defaults
  [SWF(width = "800", height = "600")]

  public class FLVPlayer extends Sprite {

    private static const CUT_FRAME_VALUE: int = 20;
    private static const INFO_EMPTY: Object = {
      duration: null,
      width: null,
      height: null,
      fps: null
    };

    private static const CAN_PLAY_THROUGH: String = "canplaythrough";
    private static const CAN_PLAY: String = "canplay";
    private static const LOADED_METADATA: String = "loadedmetadata";
    private static const TIME_UPDATE: String = "timeupdate";
    private static const PROGRESS: String = "progress";
	private static const PLAYING:String = "playing";

    private var video: Video;
    private var nc: NetConnection;
    private var ns: NetStream;
    private var info: Object = INFO_EMPTY;
    private var listener: Object;
    
    private var cutFrameCounter: int = CUT_FRAME_VALUE;

    //js properties
    private var autoplay: Boolean = false;
    private var src: String = null;
    private var currentTime: Number = -1;
    private var duration: Number = -1;
    private var loop: Boolean = false;
    private var muted: Boolean = false;
    private var paused: Boolean = false;
    private var played: Boolean = false;
    private var volume: Number = 1;
    private var buffered: Number = -1;

    public function FLVPlayer() {
      this.addEventListener(Event.ADDED_TO_STAGE, init, false, 0, true);
    }

    private function init(event: Event): void {
      this.removeEventListener(Event.ADDED_TO_STAGE, init);

      initInterface();
      initStage();
      initVideo();
    }

    private function initVideo(): void {
      video = new Video(640, 480);
      video.x = 0;
      video.y = 0;
      video.width = stage.stageWidth;
      video.height = stage.stageHeight;

      initStream();
      attachListener();
      //ns.play(src);
      ns.addEventListener(NetStatusEvent.NET_STATUS, onStatus, false, 0, true);
      this.addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
      updateState({
        play: true,
        pause: false
      });

      this.addChild(video);
    }

    private function initStream(): void {
      nc = new NetConnection();
      nc.connect(null);
      ns = new NetStream(nc);
      video.attachNetStream(ns);
    }

    private function initStage(): void {
      stage.displayState = StageDisplayState.NORMAL;
      stage.align = StageAlign.TOP;
    }

    private function initInterface(): void {
      if (ExternalInterface.available) {
        ExternalInterface.addCallback("play", jsPlay);
        ExternalInterface.addCallback("stop", jsStop);
        ExternalInterface.addCallback("pause", jsPause);
        ExternalInterface.addCallback("load", jsLoad);
        ExternalInterface.addCallback("set", jsSetProperty);
      }
    }

    private function updateState(state: Object): void {
      played = state.play === true;
      paused = state.pause === true;

      if (played && !this.hasEventListener(Event.ENTER_FRAME)) {
        this.addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
      } else {
        this.removeEventListener(Event.ENTER_FRAME, onEnterFrame, false);
      }
    }

    private function attachListener(): void {
      listener = new Object();
      listener.onMetaData = function(_info: Object): void {
        for (var i: String in _info) {
          info[i] = _info[i];
        }
        info.videoWidth = info.width;
        info.videoHeight = info.height;
        info.src = src;
        jsUpdateProperties(info);
        info.ready = true;
        jsEventFire(LOADED_METADATA);
        jsEventFire(CAN_PLAY_THROUGH);
      }
      if (!ns) {
        initStream();
      }
      ns.client = listener;
    }

    private function onStatus(e: NetStatusEvent): void {
      if (e.info.level == "status") {
        if(e.info.code == "NetStream.Buffer.Full") {
          currentTime = 0;
          buffered = ns.bufferLength;
          jsUpdateProperties({
            buffered: [{start: function() {return 0}, end:function() {return buffered}}],
            currentTime: currentTime
          });
          jsEventFire(CAN_PLAY_THROUGH);
        } else if(e.info.code == "NetStream.Play.Stop") {
		  jsStop();
		}
      }
    }

    private function onEnterFrame(e: Event): void {
      currentTime = ns.time;
      buffered = ns.bufferLength;
      jsUpdateProperties({
        currentTime: currentTime,
        buffered: [{start: function() {return 0}, end:function() {return buffered}}],
        muted: muted,
		paused: paused
      });
      jsEventFire(TIME_UPDATE);
      if (cutFrameCounter <= 0) {
        jsEventFire(PROGRESS);
        cutFrameCounter = CUT_FRAME_VALUE;
      } else {
        cutFrameCounter--;
      }
    }

    //js methonds

    public function jsPlay(): void {
      try {
        if (paused) {
          ns.resume();
        } else {
          ns.play(src);
        }
		jsEventFire(PLAYING);
        updateState({
          play: true,
          pause: false
        });
      } catch (e: Error) {
        trace(e);
      }
    }
    public function jsStop(): void {
      try {
        ns.pause();
        ns.seek(0);
        updateState({
          play: false,
          pause: false
        });
      } catch (e: Error) {
        trace(e);
      }
    }
    public function jsPause(): void {
      try {
        ns.pause();
        updateState({
          play: false,
          pause: true
        });
      } catch (e: Error) {
        trace(e);
      }
    }
    public function jsLoad(_src: String): void {
      src = _src;
      ns.play(src);
      if (!autoplay) {
        ns.pause();
        updateState({
          play: false,
          pause: false
        });
      }
    }

    //js properties
    public function jsSetProperty(name: String, value: * ): void {
      try {
        var st: SoundTransform;
        switch (name) {
          case "volume":
            st = new SoundTransform(value);
            ns.soundTransform = st;
            break;
          case "src":
            if (src != value) {
              src = value;
              buffered = -1;
              info = INFO_EMPTY;
              ns.play(src);
              updateState({
                play: true,
                pause: false
              });
            }
            break;
          case "muted":
            st = new SoundTransform(value ? volume : 0);
            ns.soundTransform = st;
            muted = value;
            break;
          case "currentTime":
            ns.seek(value);
            break;
        }
      } catch (e: Error) {
        trace("unable to set property " + name + "\r" + e);
      }
    }

    public function jsEventFire(type: String): void {
      if (ExternalInterface.available) {
        if (type == CAN_PLAY_THROUGH || type == CAN_PLAY) {
          if (buffered == -1 || !info.ready) {
            trace("Can't play. buffered:" + buffered + ", metadata ready:" + info.ready);
            return;
          }
        }

        ExternalInterface.call("FLVP_EventFire", type);
      }
    }

    public function jsUpdateProperties(properties: Object): void {
      if (ExternalInterface.available) {
        ExternalInterface.call("FLVP_UpdateProperties", properties);
      }
    }
  }
}