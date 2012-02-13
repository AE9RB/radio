# Twenty-First Century Amateur Radio

An http server for interactive signal processing.

The lack of an SDR application that does both voice and data has generated
a lot of interest in transporting PCM and I/Q data over networks and between
applications. Rather than present another solution to produce and consume audio
streams, this project is focusing on a solution that enables development of
HTML and Javascript radios with automation and mailbox capabilities.

## Status

HTTP Server: Working
Spectrum Analyzer: Working
Rig Control: current WIP
PSK31: LPCM only, next WIP
SSB: Not Started
CW: Not Started
User Interface: Proof-of-concept, please contribute
More drivers: always a WIP, please contribute

## Installation

Please use the wiki for verbose install directions: https://github.com/ham21/radio/wiki

### Dependencies

Ubuntu and Debian:

    sudo apt-get install alsa-base libusb-1.0 build-essential libfftw3-dev libz-dev libssl-dev libreadline-dev
    sudo usermod -a -G audio your_username
    
Apple OSX using ports:

    port install fftw-3 libusb

Apple OSX using homebrew:

    brew install fftw libusb
    
Windows does not have dependencies; begin with Ruby install.
    
### Ruby

This project requires Ruby 1.9. If your OS came with Ruby, it's likely 1.8
and not suitable. Your choice to install Ruby 1.9 directly or with the rvm
tool. Rubinius should work in 1.9 mode but JRuby will not.

http://www.ruby-lang.org/
or
http://beginrescueend.com/rvm/install/

### Ruby Gems

Install the radio software and operating system specifics for Ruby.

Linux:

    gem install radio alsa

Apple OSX:

    gem install radio coreaudio
    
Windows:

    gem install radio win32-sound

## Operation

Execute ```radio-server``` then open your web browser to http://localhost:7373/
