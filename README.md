# Twenty-First Century Amateur Radio

An http server for interactive digital signal processing.
The mission is to find a solution that enables development of radios
using open and approachable technologies such as HTML and Javascript.

## Status

 * HTTP Server: Working
 * Spectrum Analyzer: Working
 * Rig Control: Working
 * SSB: Working
 * PSK31: Working, no UI
 * CW: AF mode started
 * Transmit: not yet
 * User Interface: experimental, please contribute
 * More drivers: always a WIP, please contribute

## Installation

Please use the wiki for verbose install directions: https://github.com/ham21/radio/wiki

### Dependencies

Debian and Ubuntu:

    sudo apt-get install ruby-dev alsa-base libusb-1.0 build-essential libfftw3-dev libz-dev libssl-dev libreadline-dev
    sudo usermod -a -G audio your_username
    
Apple OSX using ports:

    port install fftw-3 libusb

Apple OSX using homebrew:

    brew install fftw libusb
    
Windows needs fftw3 installed but the install process is not yet known.
    
### Ruby

This project requires Ruby 1.9. Ruby 1.8 is not fast enough and JRuby will not work.

### Ruby Gems

Install the radio software and operating system specifics for Ruby.

Linux:

    gem install radio ruby-alsa

Apple OSX:

    gem install radio coreaudio
    
Windows:

    gem install radio win32-sound

## Operation

Execute ```radio-server``` then open your web browser to http://localhost:7373/
