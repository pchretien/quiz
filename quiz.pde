// Quiz
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License Version 2
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// You will find the latest version of this code at the following address:
// http://github.com/pchretien
//
// All uodates will be published on http://www.basbrun.com

#include <AF_Wave.h>
#include <avr/pgmspace.h>
#include "util.h"
#include "wave.h"

AF_Wave card;
File f;
Wavefile wave;

// 74HC595 pins
const int latchPin = 6;
const int clockPin = 7;
const int dataPin = 8;

// Boutons
const int resetButton = 9;
const int numberOfButtons = 8;
const int LEDs[] = {3,2,1,0,7,6,5,4};
const int buttons[] = {0,1,19,18,14,15,16,17};

boolean ready = false;
boolean ready2 = true;

uint16_t samplerate;
int tracknum = 0;
char nameBlue[8] = "01.WAV";
char nameRed[8] = "01.WAV";

void setup() {
  // 74HC595 pins
  pinMode(latchPin, OUTPUT);
  pinMode(dataPin, OUTPUT);  
  pinMode(clockPin, OUTPUT);  
  
  // Wave shield pins
  pinMode(2, OUTPUT); 
  pinMode(3, OUTPUT);
  pinMode(4, OUTPUT);
  pinMode(5, OUTPUT);
  
  // Buttons ...
  pinMode(resetButton, INPUT);
  for( int i=0; i<numberOfButtons; i++)
    pinMode(buttons[0], INPUT);
    
  if (!card.init_card()) 
  {
    registerBlink(4, 1);
    return;
  }
  if (!card.open_partition()) 
  {
    registerBlink(4, 2);
    return;
  }
  if (!card.open_filesys()) {
    registerBlink(4, 3); 
    return;
  }

 if (!card.open_rootdir()) {
    registerBlink(4, 4);
    return;
  }
  
  registerBlink(3, 2);
  
  reset();
}

void loop()
{  
  if(digitalRead(resetButton) == HIGH)
  {
    if(!ready)
    {
      reset();
      return;
    }
    
    if(ready2)
    {
      int button = checkButtons();
      if(button > -1)
        teamSelection(button);
    }
    else
    {
      int button = checkButtons();
      if(button < 0)
        ready2 = true;
    }
    
    return;
  }
  
  if(!ready)
    return;    
  
  // Armed ... check for the first button to trigger
  int button = checkButtons();
  if(button > -1)
    processResponse(button);
}

int checkButtons()
{
  if(digitalRead(buttons[0]) == LOW)
    return 0;
          
  for(int i=1; i<numberOfButtons; i++)
  {      
    if(digitalRead(buttons[i]) == HIGH)
      return i;
  }
  
  return -1;
}

void processResponse( int buttonId )
{
  ready = false;
  registerWrite(LEDs[buttonId], HIGH);
  
  card.reset_dir();
  if(buttonId < 4 )
    playcomplete(nameBlue);
  else
    playcomplete(nameRed);
}

void registerWrite(int whichPin, int whichState) {
  byte bitsToSend = 0;
  
  digitalWrite(latchPin, LOW);
  bitWrite(bitsToSend, whichPin, whichState);
  shiftOut(dataPin, clockPin, MSBFIRST, bitsToSend);
  digitalWrite(latchPin, HIGH);  
}

void reset()
{
  ready = true;
  byte bitsToSend = 0;
  digitalWrite(latchPin, LOW);
  shiftOut(dataPin, clockPin, MSBFIRST, bitsToSend);
  digitalWrite(latchPin, HIGH);
}

void registerBlink(int led, int j)
{
  for(int i=0; i<j; i++)
  {
    registerWrite(led, HIGH);
    delay(1000);
    registerWrite(led, LOW);
    delay(1000);
  }
}

void playcomplete(char *name) 
{
  uint16_t potval;
  uint32_t newsamplerate;
  
  playfile(name);
  samplerate = wave.dwSamplesPerSec;

  while(wave.isplaying)
  {
  }
  
  card.close_file(f);
}


void playfile(char *name) 
{
   f = card.open_file(name);
  if (!f) 
  {
    registerBlink(4, 5);
     return;
  }
  if (!wave.create(f)) 
  {
    registerBlink(4, 6);
    return;
  }
  
  // ok time to play!
  wave.play();
}

void teamSelection( int buttonId )
{
  char name[8];
  
  ready2 = false;   
  card.reset_dir();
  // scroll through the files in the directory
  for (int i=0; i<=tracknum; i++) {
    uint8_t r = card.get_next_name_in_dir(name);
    if (!r) 
    {
      // ran out of tracks! start over
      tracknum = 0;
      card.reset_dir();
      r = card.get_next_name_in_dir(name);
      if (!r) 
        return;
        
      break;
    }
  }
  
  // Play the wav file
  card.reset_dir();
  playcomplete(name);
  
  // Set the name as the team sound
  char* dest = NULL;
  if(buttonId < 4 )
    dest = nameBlue;
  else
    dest = nameRed;
    
  for(int i=0; i<8; i++)
    dest[i] = name[i];
  
  tracknum++;
}

