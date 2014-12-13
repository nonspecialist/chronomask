import processing.video.*;
import controlP5.*;
import java.util.Arrays;
import java.util.Date;

java.awt.Insets insets;

// How coarse should we make the gradient (lower == thinner slices)
int coarseness = 8;
int levels = 0;

String maskdir = "/home/cmp/sketchbook/chronomask/data";

boolean need_movie = true;
boolean need_mask = true;

//
// ---------------------------------------------------------------------------
// encapsulates camera input, or video files from disk

class VideoThing {
  Movie movie;
  Capture cam;

  private boolean doing_setup = true;
  private boolean be_synchronous = false;
  private boolean running = true;
  private boolean is_ready = false;
  private PApplet parent;

  public int videox, videoy;

  // our default constructor tries to determine whether to use a Capture or a Movie
  // as the video input
  VideoThing(PApplet p) {
    parent = p;
    String[] cameras = Capture.list();
    if (0 == cameras.length) {
      // This uses a callback to return the movie path
      println("There are no cameras");
      selectInput("Select a movie to chronomask ...", "loadMovie");
    } else {
      load_capture(cameras);
    }
  }
  
  boolean ready() {
    return is_ready;
  }

  boolean running() {
    return running;
  }

  int width() {
    return videox;
  }

  int height()  {
    return videoy;
  }

  color get_pixel(int pixel_offset) {
    if (null != cam) {
      // println("cam.get_pixel(" + pixel_offset + ")");
      cam.loadPixels();
      return cam.pixels[pixel_offset];
    } else {
      movie.loadPixels();
      return movie.pixels[pixel_offset];
    }
  }
  
  void set_stream(Movie m) {
    movie = m;
    movie.loop();
    movie.volume(1);
    movie.read();
    videox = movie.width; videoy = movie.height;
    need_movie = false;
    is_ready = true;
    cam = null;
  }

  void draw() {
    if (null == movie) {
      draw_cam();
    } else {
      draw_movie();
    }
  }

  private void load_capture(String[] cameras) {
    println("Available cameras:");
    for (int i=0; i<cameras.length; i++) {
      println("    [" + i + "]: " + cameras[i]);
      if (cameras[i].equals("name=/dev/video0,size=640x480,fps=25")) {
        println("Choosing camera [" + i + "]: " + cameras[i]);
        cam = new Capture(parent, cameras[i]);
        break;
      }
    }
    
    if (null != cam) {
      cam.start();
      while (!cam.available()) {
        Thread.yield();
      }
      cam.read();
      videox = cam.width; videoy = cam.height;
      println("Loaded camera with size " + videox + "x" + videoy);
    }

    need_movie = false;
    is_ready = true;
  }

  private void draw_movie() {  
    if (movie.available()) {
      movie.read();
      movie.loadPixels();

      if (be_synchronous) {
        movie.pause();
      }
      
      if (doing_setup) {
        setup_movie();
      }
      
      if (be_synchronous) {
        movie.play();
      }
    } else if (movie.time() >= movie.duration()) {
      running = false;
      if (levels-- == 0) {
        movie.stop();
        println("Reached end of input movie");
      }
    }
  }
  
  boolean available() {
    if (null != cam) {
      return cam.available();
    } else {
      return movie.available();
    }
  }
  
  void read() {
    if (null != cam) {
      cam.read();
    } else {
      movie.read();
    }
  }

  private void draw_cam() {
    if (cam.available()) {
      cam.read();
      cam.loadPixels();

      if (doing_setup) {
        setup_cam();
      }
    }
  }

  private void setup_cam() {
    common_setup(cam);
  }

  void setup_movie() {
    common_setup(movie);
    movie.jump(0);
  }

  void common_setup(PImage thing) {
    println("Setting up ...");
    chronomask.resize(thing.width, thing.height);
    videox = thing.width; videoy = thing.height;
    doing_setup = false;
  }

}

// ---------------------------------------------------------------------------
// The ChronoMask is the thing that determines how we distort/delay the VideoThing
class ChronoMask {
  private PApplet parent;
  private PImage _chronomask;
  private File defaultMask = new File(maskdir + "/zero_change_all_black.png");
  private boolean is_ready = false;
  // Hold the size we want to end up at (set from the video stream)
  private int intended_x; private int intended_y;

  ChronoMask(PApplet p) {
    parent = p;
    this.load();
  }
  
  ChronoMask(PApplet p, int sizex, int sizey) {
    parent = p;
    intended_x = sizex; intended_y = sizey;
    this.load();
  }
  
  boolean ready() {
    return is_ready;
  }

  int width() {
    return _chronomask.width;
  }

  int height() {
    return _chronomask.height;
  }
  
  color get_pixel(int pixel_offset) {
    // println("chronomask.get_pixel(" + pixel_offset + ")");
    return _chronomask.pixels[pixel_offset];
  }

  void load() {
    selectInput("Select a mask file", "loadMask", defaultMask);
  }

  void load(String path) {
    println("Load new chronomask from "  + path);
    _chronomask = loadImage(path);
    _chronomask.loadPixels();
    this.resize();
    is_ready = true;
    need_mask = false;
  }

  // set the current mask to a specific image
  void set(PImage img) {
    _chronomask = img;
  }

  // change the mask size to match the size of the video stream
  void resize() {
    println("Got chronomask " + this.width() + "x" + this.height());
    println("Got video " + intended_x + "x" + intended_y);
    if ((intended_x != this.width()) || (intended_y != this.height())) {
      println("NOTICE: Mask (" 
              + this.width()+ "x" + this.height() + 
              ") and video size (" 
              + intended_x + "x" + intended_y + 
              ") mismatch, resizing chronomask");
      PImage newmask = new PImage(intended_x, intended_y);
      newmask.copy(_chronomask, 0, 0, this.width(), this.height(), 0, 0, intended_x, intended_y);
      _chronomask = newmask;
    }
    _chronomask.loadPixels();
  }

  void resize(int sizex, int sizey) {
    intended_x = sizex; intended_y = sizey;
    this.resize();
  }

  // flip the mask data top to bottom
  void flip_vertical() {
    PImage newmask = new PImage(this.width(), this.height());
    for (int i=0; i < this.height(); i++) {
      for (int j=0; j < this.width(); j++) {
        newmask.set(j, i, _chronomask.get(j, this.height() - i));
      }
    }
    _chronomask = newmask;
    _chronomask.updatePixels();
    _chronomask.loadPixels();
  }

  // flip the mask data left to right
  void flip_horizontal() {
    PImage newmask = new PImage(this.width(), this.height());
    for (int i=0; i < this.height(); i++) {
      for (int j=0; j < this.width(); j++) {
        newmask.set(j, i, _chronomask.get(this.width() - j, i));
      }
    }
    _chronomask = newmask;
    _chronomask.updatePixels();
    _chronomask.loadPixels();
  }

  // Load in a random mask file from the default mask directory
  void load_random() {
    File maskDir = new File(maskdir);
    ArrayList masks = new ArrayList<String>(Arrays.asList(maskDir.list()));
    // select only files that match *.png/jpg
    for (int i=0; i<masks.size(); i++) {
      String foo = (String) masks.get(i);
      if (foo.equals(".") || foo.equals("..")) {
        masks.remove(i);
      }

      if ((! foo.endsWith(".png")) || (! foo.endsWith(".jpg"))) {
        masks.remove(i);
      }
    }
    
    String randomMask = (String) masks.get(int(random(0, masks.size())));
    
    println("Chose random mask " + randomMask);
    this.load(maskdir + "/" + randomMask);
  }

}

class FrameStack {
  // holds the frames we're working on
  ArrayList<PImage> frames;

  FrameStack(int levels, int sizex, int sizey) {
    // create a stack of blank frames, the depth of the number of levels
    frames = new ArrayList<PImage>();
    println("Creating base frame stack of " + levels + " frames");
    for (int i = 0; i < levels; i++) {
      PImage tmp = new PImage(sizex, sizey);
      tmp.loadPixels();
      frames.add(tmp);
    }
  }

  PImage rotate() {
    // now display the front frame
    PImage front_frame = frames.remove(0);
    front_frame.updatePixels();
    // Move it to the back, reuse
    frames.add(frames.size(), front_frame);
    return front_frame;
  }

  void put_pixel(int framenr, int pixel_offset, color pixel) {
    frames.get(framenr).pixels[pixel_offset] = pixel;
  }
  
  void blend_pixel(int framenr, int pixel_offset, color pixel, int mode) {
    color tmp = frames.get(framenr).pixels[pixel_offset];
    frames.get(framenr).pixels[pixel_offset] = blendColor(tmp, pixel, mode);
  }
  
  void unblend_pixel(int framenr, int pixel_offset, color pixel, int mode) {
    color tmp = frames.get(framenr).pixels[pixel_offset];
    frames.get(framenr).pixels[pixel_offset] = blendColor(tmp, pixel, mode);
  }

  color get_pixel(int framenr, int pixel_offset) {
    return frames.get(framenr).pixels[pixel_offset];
  }
  
  PImage last() {
    return frames.get(frames.size() - 1);
  }
}

// Objects that we actually use
VideoThing video;
ChronoMask chronomask;
FrameStack framestack;
PImage display_buf;

// DOCUMENTATION FOR FUTURE ENUM
// Processing can't handle enums natively at the moment
// 
// Video Warp/Twork Modes
// 1 - chrono_delay
// 2 - image overlay
// 3 - use the last frame in the stack as the chronomask
//
// Thoughts for future modes:
// - use a video stream as the chronomask itself (other than the simple
//   feedback we use in method 3)
// - instead of copying the pixel deeper into the framestack, copy just the
//   brightness, the absolute chroma, or the R, G, or B values

int twork_mode = 1;
int MAX_TWORK = 4;

// how to blend frames in blend mode
int blend_mode = LIGHTEST;

// FPS to aim for
int FPS = 25;

// Whether or not to show the loaded mask by default ('o' key)
boolean show_mask = true;

// debugging?
boolean debug = false;

// how to transfer the chronomasked image into the display buffer
TransferMode transfer_mode = TransferMode.MODE_COPY;

// These need to be external to the classes, as they're used as callbacks 
// by framework functions.
// 
// Callback from selectInput()
void loadMovie(File path) {
  if (null != path) {
    video.set_stream(new Movie(this, path.getAbsolutePath()));
    framestack = new FrameStack(levels, video.width(), video.height());
    chronomask.resize(video.width(), video.height());
    size(video.width(), video.height());
    frame.setSize(
        video.width() + insets.left + insets.right, 
        video.height() + insets.top + insets.bottom
    );
  }
}

// callback from selectInput()
void loadMask(File path) {
  if (null != path) {
    chronomask.load(path.getAbsolutePath());
    chronomask.resize(video.width(), video.height());
    // copy the mask itself into all frames of the stack so that
    // we can see what it looks like before overwriting it with the
    // video feed
    if (show_mask) {
      for (int frame_nr = 0; frame_nr < levels; frame_nr++) {
        for (int i = 0; i < (chronomask.width() * chronomask.height()); i++) {
          framestack.put_pixel(frame_nr, i, chronomask.get_pixel(i));
        }
      }
    }
  }
  // nothing chosen, so we'll just carry on with the current mask
  need_mask = false;
}

// ------------------------------------
// callbacks used by the Processing framework itself
//

// - setup is used to initialize the environment. It's called once only.
void setup() {
  frameRate(FPS);
  background(color(0));
  frame.pack();
  insets = frame.getInsets();

  video = new VideoThing(this);
  
  // Wait until we have a running video object before loading the
  // chronomask, otherwise we don't know what size to make it
  while (!video.ready()) {
    Thread.yield();
  }
  
  println("Got video with size " + video.width() + "x" + video.height());
  chronomask = new ChronoMask(this, video.width(), video.height());
  
  while (!chronomask.ready()) {
    Thread.yield();
  }
  
  println("Canvas size setting to " + video.width() + "x" + video.height());
  frame.setResizable(true);
  frame.setSize(
      video.width() + insets.left + insets.right, 
      video.height() + insets.top + insets.bottom
  );
  size(video.width(), video.height());
  frame.setLocation(0, 0);

  levels = round(min(video.width(), video.height())/coarseness);
  println("Generating " + levels + " levels with coarseness " + coarseness);

  framestack = new FrameStack(levels, video.width(), video.height());
  display_buf = new PImage(width, height);
}

// -- draw is called once per frame
void draw() {
  if (need_movie || need_mask) {
    return;
  }
  
  if (video.available()) {
    video.read();
  }
  
  Date pre_twork = new Date();
  if (video.running()) {
    int to_frame_nr;
    // so now we have a new frame ... according to the values in the chronomask,
    // we copy pixels into the frame stack at that depth (so a value of zero means
    // copy into the front of the frame stack, a value of 17 means copy that pixel 
    // into the 17th frame.
    for (int i = 0; i < (chronomask.width() * chronomask.height()); i++) {
      switch (twork_mode) {
        case 1: // CHRONO DELAY BASED ON MASK BRIGHTNESS
          // We use map to bring the potential full range of brightnesses into
          // the range of the number of levels that we have
          to_frame_nr = int(map(brightness(chronomask.get_pixel(i)), 0, 255, 0, (levels - 1)));
          switch (transfer_mode) {
            case MODE_COPY:
              framestack.put_pixel(to_frame_nr, i, video.get_pixel(i)); break;
            case MODE_BLEND:
              int prev_frame_nr = to_frame_nr - levels;
              if (prev_frame_nr < 0) {
                prev_frame_nr = levels - 1;
              }
              framestack.blend_pixel(to_frame_nr, i, video.get_pixel(i), blend_mode);
              framestack.unblend_pixel(prev_frame_nr, i, video.get_pixel(i), REPLACE);
              break;
          }
          break;
        case 2: // a simple image overlay of the mask on top of the video
          framestack.put_pixel(0, i, blendColor(video.get_pixel(i), chronomask.get_pixel(i), SOFT_LIGHT));
          break;
        case 3: // first frame is the new chronomask, use the chrono_delay code
          // This doesn't work very well, it's quite expensive 
          to_frame_nr = int(map( brightness(framestack.get_pixel(0, i)), 0, 255, 0, (levels - 1)));
          framestack.put_pixel(to_frame_nr, i, video.get_pixel(i));
          break;   
        case 4: // RGB test mode
          int red_val = chronomask.get_pixel(i) >> 16 & 0xFF;
          to_frame_nr = int(map(red_val, 0, 255, 0, (levels - 1)));
          int red_pixel = video.get_pixel(i) >> 16 & 0xFF;
          framestack.put_pixel(to_frame_nr, i, red_pixel );
          break;
        default:
          println("Unknown mode " + twork_mode);
          break;
      }
    }
  }
  
  Date pre_resize = new Date();
  
  // scale the image to the frame size. We create a copy of the image here
  if (display_buf.width != width || display_buf.height != height) {
    println("display_buf needs to be resized to " + width + "x" + height);
    display_buf.resize(width, height);
  }
  
  Date pre_copy = new Date();
  // because rotating the framestack only returns a pointer to the frame,
  // and if we resize that, we end up breaking the framestack 
  display_buf.copy(framestack.rotate(),
               0, 0, video.width(), video.height(),
               0, 0, display_buf.width, display_buf.height);
                   
  Date pre_update = new Date();
  display_buf.updatePixels();
  // println("Chronomask is " + chronomask.width() + "x" + chronomask.height() + ", " + 
  //  "Video is " + video.width() + "x" + video.height() + ", " +
  //  "Scaling image to " + width + "x" + height);
  
  Date pre_set = new Date();
  set(0, 0, display_buf);
  
  Date end_draw = new Date();
  long twork_time = pre_resize.getTime() - pre_twork.getTime();
  long resize_time = pre_copy.getTime() - pre_resize.getTime();
  long copy_time = pre_update.getTime() - pre_copy.getTime();
  long update_time = pre_set.getTime() - pre_update.getTime();
  long set_time = end_draw.getTime() - pre_set.getTime();
  long total_time = end_draw.getTime() - pre_twork.getTime();
  float fps_max = FPS;
  if (total_time != 0) {
    fps_max = 1 / ((float)total_time / 1000);
    if (fps_max > FPS) {
      fps_max = FPS;
    }
  }

  if (debug) { 
    print("Timing: twork: " + twork_time +
      ", resize: " + resize_time +
      ", copy: " + copy_time +
      ", update: " + update_time +
      ", set: " + set_time +
      ", TOTAL: " + total_time +
      ", fps: " + fps_max +
      "\r"
    );
  }
  
  if (fps_max < FPS) {
    println("WARNING: Cannot achieve desired framerate (" + fps_max + " < " + FPS + ")");
  }
}

void keyPressed() {
  // choose a mask
  // makey makey note -- this probably isn't as useful or easy in that context, so 
  // map it to something that makey makey can't easily do
  if (key == 'm' || key == 'M') {
    // pause the drawing until we have the new mask loaded and resized
    // otherwise we'll have a size mismatch
    println("Loading a new chronomask");
    need_mask = true;
    chronomask.load();
    return;
  }
  
  // flip mask vertically
  // makey makey note -- arrows like, er, up and down
  //           ^
  //           |
  //           V
  if (key == 'w' || key == 'W') {
    println(millis() + " - vertical flip");
    chronomask.flip_vertical();
    return;
  }
  
  // flip mask horizontally
  // makey makey note -- arrows like <->
  if (key == 'a' || key == 'A') {
    println("horizontal flip");
    chronomask.flip_horizontal();
    return;
  }
  
  // choose random mask 
  // makey makey note -- something like a giant question mark
  if (key == 'd' || key == 'D') {
    println("Load random chronomask");
    chronomask.load_random();
    // copy the mask itself into all frames of the stack so that
    // we can see what it looks like before overwriting it with the
    // video feed
    if (show_mask) {
      for (int frame_nr = 0; frame_nr < levels; frame_nr++) {
        for (int i = 0; i < (chronomask.width() * chronomask.height()); i++) {
          framestack.put_pixel(frame_nr, i, chronomask.get_pixel(i));
        }
      }
    }
    return;
  }
  
  // Change the tworking mode
  if (key == 'x' || key == 'X') {
    twork_mode++;
    if (twork_mode > MAX_TWORK) {
      twork_mode = 1;
    }
    switch (twork_mode) {
      case 1: println("chrono_delay brightness mode"); break;
      case 2: println("image overlay mode"); break;
      case 3: println("first-frame chrono_delay mode"); break;
      case 4: println("chrono_delay red test"); break;
      default: println("Unknown mode!"); break;
    }
    return;
  }
  
  // change between copy and blend
  if (key == 'c' || key == 'C') {
    transfer_mode = TransferMode.MODE_COPY;
    println("Switching to COPY mode");
    return;
  }
  if (key == 'b' || key == 'B') {
    transfer_mode = TransferMode.MODE_BLEND;
    println("Switching to BLEND mode");
    println("BLEND mode is " + blend_mode);
    return;
  }
  
  if (key == 'l' || key == 'L') {
    switch (blend_mode) {
      case BLEND:      blend_mode = ADD;        break;
      case ADD:        blend_mode = SUBTRACT;   break;
      case SUBTRACT:   blend_mode = DARKEST;    break;
      case DARKEST:    blend_mode = LIGHTEST;   break;
      case LIGHTEST:   blend_mode = DIFFERENCE; break;
      case DIFFERENCE: blend_mode = EXCLUSION;  break;
      case EXCLUSION:  blend_mode = MULTIPLY;   break;
      case MULTIPLY:   blend_mode = SCREEN;     break;
      case SCREEN:     blend_mode = OVERLAY;    break;
      case OVERLAY:    blend_mode = HARD_LIGHT; break;
      case HARD_LIGHT: blend_mode = SOFT_LIGHT; break;
      case SOFT_LIGHT: blend_mode = DODGE;      break;
      case DODGE:      blend_mode = BURN;       break;
      case BURN:       blend_mode = BLEND;      break;
      default:
        println("Do not know current blend mode");
        blend_mode = BLEND;
        break;
    }
    println("BLEND mode is " + blend_mode);
  }
  
  // flip whether to show the mask after loading it
  if (key == 'o' || key == 'O') {
    show_mask = !show_mask;
    if (show_mask) {
      println("Showing mask after loading");
    } else {
      println("Not showing mask after loading");
    }
    return;
  }
  
  // turn debugging on and off
  if (key == 'g' || key == 'G') {
    debug = !debug;
    return;
  }

  // reset everything
  if (key == 't' || key == 'T') {
      blend_mode = BLEND;
      twork_mode = 1;
      show_mask = true;
      transfer_mode = TransferMode.MODE_COPY;
      chronomask.load(maskdir + "/linear_top_down.png");
  }
  
  if (key == 'v' || key == 'V') {
    need_movie = true;
    selectInput("Select a movie to chronomask ...", "loadMovie");
    return;
  }
}
