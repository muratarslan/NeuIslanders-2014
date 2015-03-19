//#define DEBUG
// timer 4 channel 4
#define DUTY 2 // 2 %50 4 %25

HardwareTimer timer(4);

int robotId = 0;
int chargeBegin = 0;

//                 PWM DIR BRE
int motors[4][3] = {{5, 17, 18},   // RF
                    {9, 15, 16},   // LF
                    {6, 8, 7},      
                    {10, 19, 20}}; // RR
                    
int chargeTone = 3;
int chargePin = 4;
int kickerRelease = 2;
int spinnerPin = 13;

bool breaks[4] = {true, true, true, true};
int cmdBuffer[5];

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
    }
    else{
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

// freq in Hz    duration in ms
void tone(int pin, int freq) {
    timer.pause();
    pinMode(pin,PWM);
    timer.setPrescaleFactor(72);  // microseconds
    timer.setOverflow(1000000/freq);
    timer.setMode(TIMER_CH4,TIMER_PWM);
    timer.setCompare(TIMER_CH4,1000000/freq/DUTY);
    timer.setCount(0);  
    timer.refresh(); // start it up
    timer.resume();
    delay(10);
    timer.pause();
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

  digitalWrite(kickerRelease, HIGH);
  delay(10);
  digitalWrite(kickerRelease, LOW);
  chargeBegin = millis();
  delay(50);
  digitalWrite(chargePin, HIGH);
}

void spinnerCommand(int state){
#ifdef DEBUG
  Serial.println("Spinner");
#endif

  if (state == 1)
    digitalWrite(spinnerPin, HIGH);
  else
    digitalWrite(spinnerPin, LOW);
}

void setup(){
    Serial1.begin(57600);
    
    pinMode(kickerRelease, OUTPUT);
    pinMode(chargePin, OUTPUT);
    pinMode(chargeTone, OUTPUT);
    pinMode(spinnerPin, OUTPUT);

    digitalWrite(kickerRelease, LOW);

    for(int i = 0; i < 4; i++){
      pinMode(motors[i][0], OUTPUT);
      pinMode(motors[i][1], OUTPUT);
      pinMode(motors[i][2], OUTPUT);
      digitalWrite(motors[i][2], LOW);
    }
   
    kickCommand(0);
    tone(chargeTone, 50000);
   
#ifdef DEBUG
  Serial.println("Data Link Up");
#endif
}

void stopCharge(){
    int chargeDelta = millis() - chargeBegin;
    
    if(chargeDelta > 2000){
        digitalWrite(chargePin, LOW);
    }
}

int blockingRead(){
    while(Serial1.available() < 1)
      stopCharge();
      return Serial1.read();
}

void nextCommand(){
    while(Serial1.read() >= 0)
      stopCharge();
      
    int flag = 0;
    
    while(flag != 0xFF)
      flag = blockingRead();
}

void loop(){
  
  for(;;){
    nextCommand();
    
    while(blockingRead() != robotId){
      nextCommand();
#ifdef DEBUG
  Serial.println("Skip Cmd")l
#endif
    }
    
    cmdBuffer[0] = blockingRead();
    int cmd = cmdBuffer[0] >> 4;
    
    if(cmd == 1){
      cmdBuffer[1] = blockingRead();
      cmdBuffer[2] = blockingRead();
      cmdBuffer[3] = blockingRead();
      cmdBuffer[4] = blockingRead();
      motorCommand(cmdBuffer);
    }
    else if (cmd == 2){
      kickCommand(blockingRead());}
    else if (cmd == 3){
      spinnerCommand(blockingRead());}
    else{
#ifdef DEBUG
  Serial.println("Unknown Command.");
#endif
   }
  }
 }
      

