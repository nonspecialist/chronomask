# Chronomask

Processing code to warp and generally mess with a video stream 
(either live from a camera, or from a file loaded from disk)

## Installation

You'll need `processing` -- you can download it from
http://processing.org/

This code is known to run against Processing v3.2.1.

You'll also need the ControlP5 library -- available from
http://www.sojamo.de/libraries/controlP5/. Download the zip file and
unpack it into your ~/sketchbook/libraries folder.

## Usage

If you have a webcam, when you run the sketch you'll be asked to choose
a mask file to warp the video stream. Choose it, and away you go. By
default, the code looks for a 648x480 video stream at 25fps on
/dev/video0 -- if you're not using Linux, or your video devices don't
match that, you should change the code in `load_capture` so that it
finds something appropriate. I know, that's kind of crap.

If you don't have a webcam, it'll prompt you for a video to load,
followed by a mask file to warp it with.

I'd strongly advise against choosing video sources that are too
high-res; much above 640x480 will result in fairly poor performance.
Resizing video before playing with it is probably a good idea.

### Key bindings

While video is playing, you can use the following keypresses to change
state:

    * `m`
        * load a new mask image
    * `w`
        * flip the mask image vertically
    * `a`
        * flip the mask image horizontally
    * `d`
        * choose a random mask image
    * `x`
        * change the rendering mode; successive presses will cycle
          through:
            * chronomask brightness mode (where the brightness of the
              imported mask file determines the temporal delay of each
              pixel)
            * image overlay mode (where the mask file is simply overlaid
              on the video stream with no temporal effects)
            * first-frame chronomask brightness mode (honestly, I can't
              remember)
            * chronomask red channel delay mode, where we only delay
              video by the red input channel of the mask file
    * `v`
        * load a video file -- you can use this to switch from a webcam
          input to a video file input.
