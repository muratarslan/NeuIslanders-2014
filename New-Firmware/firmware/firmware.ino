
//#define DEBUG
#include <Servo.h>

int robotId = 0;

//                   PWM DIR BRE
int motors[4][3] = {{5,  A2, A3},  //RF
                    {9,  A0, A1},  //LF
                    {6,   8,  7},  //RR
                    {10, A4, A5}};

int chargeTone = 3;
int kickerRelease = 2;
int spinnerPin = 13;
Servo spinnerMotor;


bool breaks[4] = {true,true,true,true};
int  cmdBuffer[5];


void processMotorCommand(int* dirs,byte* pwms){
#ifdef DEBUG
  Serial.print("PWMs: ");
#endif

  for(int i=0; i<4; i++){
    int pwm = pwms[i];
    int dir = dirs[i];

#ifdef DEBUG
    Serial.print("[");
    Serial.print(dir);
    Serial.print(" ");
    Serial.print(pwm);
    Serial.print(" ");
    Serial.print(motors[i][0]);
    Serial.print("] ");
#endif

    if (pwm == 0){
      digitalWrite(motors[i][2],LOW);
      breaks[i] = true;
    }else{
      if (breaks[i] == true){
        digitalWrite(motors[i][2],HIGH);
        breaks[i] = false;
      }
      digitalWrite(motors[i][1],dir);
      analogWrite(motors[i][0],pwm);
    }
  }
#ifdef DEBUG
  Serial.print("\n");
#endif
}

void motorCommand(int* buff){
  byte cmd = ((byte)buff[0]);
  int dirs[4] = {bitRead(cmd, 3),
                 bitRead(cmd, 2),
                 bitRead(cmd, 1),
                 bitRead(cmd, 0)};

  byte pwms[4] = {(byte)buff[1],
                  (byte)buff[2],
                  (byte)buff[3],
                  (byte)buff[4]};

  processMotorCommand(dirs,pwms);
}


void kickCommand(int force){
#ifdef DEBUG
  Serial.println("Kick");
#endif

  analogWrite(kickerRelease, 100);
  delay(force);
  analogWrite(kickerRelease, LOW);
}


void escArm(){
#ifdef DEBUG
  Serial.println("escARM");
#endif
  delay(2000);
  spinnerMotor.write(0);
  digitalWrite(spinnerPin,HIGH);
  delay(100);
  digitalWrite(spinnerPin,LOW);
  delay(2000);
  spinnerMotor.write(60);
  digitalWrite(spinnerPin,HIGH);
  delay(100);
  digitalWrite(spinnerPin,LOW);
  delay(2000);
}


void spinnerCommand(int state){
#ifdef DEBUG
  Serial.println("Spinner");
#endif

  if (state == 1){
    digitalWrite(spinnerPin,LOW);
    spinnerMotor.write(250);
  }
  else
    digitalWrite(spinnerPin,HIGH);
}

void charge(){
  #ifdef DEBUG
  Serial.print("Charging!");
#endif
  int volt = analogRead(A0);
  if(volt > 340)
    noTone(chargeTone);
  if(volt < 335)
    tone(chargeTone, 20000);
}


void setup(){
  Serial.begin(57600);

  pinMode(kickerRelease, OUTPUT);
  pinMode(chargeTone, OUTPUT);
  pinMode(spinnerPin, OUTPUT);
  spinnerMotor.attach(9);

  for(int i=0; i<4; i++){
    pinMode(motors[i][0], OUTPUT);
    pinMode(motors[i][1], OUTPUT);
    pinMode(motors[i][2], OUTPUT);
    digitalWrite(motors[i][2],LOW);
  }

  escArm();

#ifdef DEBUG
  Serial.println("Data Link Up");
#endif
}


int blockingRead(){
  while (Serial.available() < 1)
  return Serial.read();
}


void nextCommand(){
  int flag = 0;
  while(flag != 0xFF)
    flag = blockingRead();
}


void loop(){
  
  for(;;){
    charge();
    nextCommand();

    while(blockingRead() != robotId){
      nextCommand();
#ifdef DEBUG
      Serial.println("Skip Cmd");
#endif
    }

    cmdBuffer[0] = blockingRead();
    int cmd = cmdBuffer[0] >> 4;

    if (cmd == 1){
      cmdBuffer[1] = blockingRead();
      cmdBuffer[2] = blockingRead();
      cmdBuffer[3] = blockingRead();
      cmdBuffer[4] = blockingRead();
      motorCommand(cmdBuffer);
    }else if (cmd == 2){
      kickCommand(blockingRead());
    }else if (cmd == 3){
      spinnerCommand(blockingRead());
    }else{
#ifdef DEBUG
      Serial.println("Unknown Command.");
#endif
    }
  }
}
