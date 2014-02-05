var FLVP_single;

var FLVP = function(_flash) {
  if (FLVP_single && FLVP_single.flash == flash) {
    return undefined;
  }
  FLVP_single = this;
  this.flash = _flash;
  this.initialized = false;

  this.properties = {
    "duration": {
      get: function() {
        return this.__duration;
      }
    },
    "fps": {
      get: function() {
        return this.__fps;
      }
    },
    "videoWidth": {
      get: function() {
        return this.__videoWidth;
      }
    },
    "videoHeight": {
      get: function() {
        return this.__videoHeight;
      }
    },
    "buffered": {
      get: function() {
        return [{
            start: function() {
              return 0;
            },
            end: function() {
              return this.__buffered
            }];
        }
      },
      "paused": {
        get: function() {
          return this.__paused;
        }
      },
      "currentTime": {
        get: function() {
          return this.__currentTime;
        },
        set: function(value) {
          this.flash.set("currentTime", value);
        }
      },
      "src": {
        get: function() {
          return this.__src;
        },
        set: function(value) {
          this.flash.set("src", value);
        }
      },
      "muted": {
        get: function() {
          return this.__muted;
        },
        set: function(value) {
          this.flash.set("muted", value);
        }
      },
      "volume": {
        get: function() {
          return this.__volume;
        },
        set: function(value) {
          this.flash.set("volume", value);
        }
      }
    }

    Object.defineProperties(FLVP.prototype, this.properties);

    return this;
  }

  FLVP.prototype.play = function() {
    this.flash.play();
  }

  FLVP.prototype.stop = function() {
    this.flash.stop();
  }

  FLVP.prototype.pause = function() {
    this.flash.pause();
  }

  FLVP.prototype.load = function(src) {
    this.flash.load(src);
  }

  //Simple events interface

  FLVP.prototype.listeners = {};

  FLVP.prototype.dispatchEvent = function(event) {
    var type = event.type;
    if (this.listeners[type] && this.listeners[type].length > 0) {
      for (var i in this.listeners[type]) {
        this.listeners[type][i](event);
      }
    }
  }

  FLVP.prototype.addEventListener = function(type, callback) {
    if (!this.listeners.hasOwnProperty(type)) {
      this.listeners[type] = [];
    }
    this.listeners[type].push(callback);
  }

  FLVP.prototype.removeEventListener = function(type, callback) {
    if (this.listeners[type] && this.listeners[type].length > 0) {
      for (var i in this.listeners[type]) {
        if (this.listeners[type][i] && this.listeners[type][i].callback == callback) {
          if (this.listeners.length > 1) {
            this.listeners[type].splice(i, 1);
          } else {
            this.removeEventListeners(type);
          }
        }
      }
    }
  }

  FLVP.prototype.removeEventListeners = function(type) {
    delete this.listeners[type];
  }

  //public static functions (called from swf)

  /* FLVP_EventFire implemented type's:
     canplay, canplaythrough, loadedmetadata, timeupdate, progress
*/

  function FLVP_EventFire(type) {
    var event = new Event(type);
    console.log('FLVP_EventFire: ' + type);
    FLVP_single.dispatchEvent(event);

    if(!this.initialized && type == "loadedmetadata") {
      this.flash.setAttribute("width", this.videoWidth);
      this.flash.setAttribute("height", this.videoHeight);
      this.initialized = true;
    }
  }

  function FLVP_UpdateProperties(properties) {
    for (var i in properties) {
      if (FLVP_single.properties[i] !== undefined) {
        FLVP_single['__' + i] = properties[i];
      } else {
        console.log("can't update undefined property " + i);
      }
    }
  }