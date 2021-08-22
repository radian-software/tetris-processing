import java.util.*;
import ddf.minim.*;

Minim minim;
AudioPlayer theme;
AudioPlayer pause;

int bgcolor = color(126);

HashSet<Integer> keysDown = new HashSet<Integer>();
int size = 20;
int fieldx = 20;
int fieldy = -40;
int fieldw = 12;
int fieldh = 24;
PFont font = createFont("Helvetica", 24);
int score = 0;
TBlock currentBlock;
SBlock sblock;
float DELAY = 60;
float timer = DELAY;
ArrayList<FBlock> flies = new ArrayList<FBlock>();
boolean active = true;
String[] blocks = {
  ".O."+
  "OO."+
  "O..", // 0 v
  ".O."+
  ".OO"+
  "..O", // 1 x
  ".O."+
  ".OO"+
  ".O.", // 2 v
  "..O"+
  "OOO"+
  "...", // 3 v
  "..."+
  "OOO"+ 
  "..O", // 4 x
  "....."+
  "....."+
  "OOOO."+
  "....."+
  ".....", // 5 v
  "OO"+
  "OO", // 6 x
};
int[] offsets = {0, 0, 0, 0, 1, 2, 0};

class TBlock {
  boolean[][] shape;
  int px, py;
  int cx, cy;
  int fill;
  int side;
  TBlock (int x_, int y_, int fill_, String shape_) {
    px = x_; py = y_; fill = fill_;
    process(shape_);
  }
  void process(String _shape) {
    assert pow(sqrt(_shape.length()), 2) == _shape.length();
    side = int(round(sqrt(_shape.length())));

    char[] chars = new char[_shape.length()];
    _shape.getChars(0, _shape.length(), chars, 0);
    boolean[][] rows = new boolean[side][side];
    boolean[] row = new boolean[side];
    for (int i=0; i<chars.length+1; i++) {
      if (i != 0 && i % side == 0) {
        rows[int(i/side)-1] = row;
        row = new boolean[side];
      }
      if (i == chars.length) break;
      row[i%side] = chars[i] == 'O';
    }
    shape = rows;
    cx = (side-1)/2;
    cy = (side-1)/2;
  }
  boolean canMoveLeft() {
    for (int y=0; y<side; y++) {
      for (int x=0; x<side; x++) {
        if (shape[y][x] && sblock.shape[py+y][px+x-1]) {
          return false;
        }
      }
    }
    return true;
  }
  boolean canMoveRight() {
    for (int y=0; y<side; y++) {
      for (int x=0; x<side; x++) {
        if (shape[y][x] && sblock.shape[py+y][px+x+1]) {
          return false;
        }
      }
    }
    return true;
  }
  boolean canMoveDown() {
    for (int y=0; y<side; y++) {
      for (int x=0; x<side; x++) {
        if (shape[y][x] && sblock.shape[py+y+1][px+x]) {
          return false;
        }
      }
    }
    return true;
  }
  boolean canRotateClockwise() {
    if (side % 2 == 0) return false;
    for (int y=0; y<side; y++) {
      for (int x=0; x<side; x++) {
        if (shape[y][x] && sblock.shape[py+rotationY(x, y)][px+rotationX(x, y)]) {
          return false;
        }
      }
    }
    return true;
  }
  boolean canExist() {
    for (int y=0; y<side; y++) {
      for (int x=0; x<side; x++) {
        if (shape[y][x] && sblock.shape[py+y][px+x]) {
          return false;
        }
      }
    }
    return true;
  }
  void moveLeft() {
    px -= 1;
  }
  void moveRight() {
    px += 1;
  }
  void moveUp() {
    py -= 1;
  }
  void moveDown() {
    py += 1;
  }
  void rotateClockwise() {
    boolean[][] newShape = new boolean[side][side];
    for (int y=0; y<side; y++) {
      for (int x=0; x<side; x++) {
        newShape[rotationY(x, y)][rotationX(x, y)] = shape[y][x];
      }
    }
    shape = newShape;
  }
  void forceDown() {
    if (canMoveDown()) {
      moveDown();
    }
    else {
      sblock.addBlock();
      sblock.checkForRows();
      generateBlock();
    }
    timer = DELAY;
  }
  void dropDown() {
    while (canMoveDown()) {
      moveDown();
      timer = DELAY;
    }
  }
  int rotationX(int _x, int _y) {
    float x = float(_x); float y = float(_y);
    return int(round(cos(PI/2) * (x - float(cx)) - sin(PI/2) * (y - float(cy)) + float(cx)));
  }
  int rotationY(int _x, int _y) {
    float x = float(_x); float y = float(_y);
    return int(round(sin(PI/2) * (x - float(cx)) + cos(PI/2) * (y - float(cy)) + float(cy)));
  }
}

class SBlock {
  boolean[][] shape;
  int[][] colors;
  SBlock () {
    shape = new boolean[fieldh][fieldw];
    colors = new int[fieldh][fieldw];
    for (int y=0; y<fieldh; y++) {
      for (int x=0; x<fieldw; x++) {
        shape[y][x] = false;
        colors[y][x] = 0;
      }
    }
    for (int y=0; y<fieldh; y++) {
      shape[y][0] = true;
      shape[y][fieldw-1] = true;
    }
    for (int x=0; x<fieldw; x++) {
      shape[0][x] = true;
      shape[fieldh-1][x] = true;
    }
  }
  void addBlock() {
    for (int y=0; y<currentBlock.side; y++) {
      for (int x=0; x<currentBlock.side; x++) {
        if (currentBlock.shape[y][x]) {
          shape[currentBlock.py+y][currentBlock.px+x] = true;
          colors[currentBlock.py+y][currentBlock.px+x] = currentBlock.fill;
        }
      }
    }
  }
  void checkForRows() {
    int foundRows = 0;
    for (int y=1; y<fieldh-1; y++) {
      boolean foundRow = true;
      for (int x=1; x<fieldw-1; x++) {
        if (!shape[y][x]) {
          foundRow = false;
          break;
        }
      }
      if (foundRow) {
        foundRows += 1;
        for (int x=1; x<fieldw-1; x++) {
          flies.add(new FBlock(float(x*size+fieldx), float(y*size+fieldy), random(5)-2.5, -random(5), colors[y][x]));
          shape[y][x] = false;
        }
        for (int z=y-1; z>0; z--) {
          for (int x=1; x<fieldw-1; x++) {
            shape[z+1][x] = shape[z][x];
            colors[z+1][x] = colors[z][x];
          }
        }
      }
    }
    switch (foundRows) {
      case 1:
        score += 1;
        break;
      case 2:
        score += 3;
        break;
      case 3:
        score += 5;
        break;
      case 4:
        score += 10;
        break;
    }
  }
}

class FBlock {
  float x, y, vx, vy;
  int fill;
  FBlock (float _x, float _y, float _vx, float _vy, int _fill) {
    x = _x;
    y = _y;
    vx = _vx;
    vy = _vy;
    fill = _fill;
  }
  void iter() {
    vx *= 0.99;
    vy += 0.2;
    x += vx;
    y += vy;
  }
}

int randint(int n) {
  return int(random(n));
}

void resetBoard() {
  sblock = new SBlock();
}

void generateBlock() {
  int type = randint(7);
  currentBlock = new TBlock(3, 2-offsets[type], color(randint(255), randint(255), randint(255)), blocks[type]);
  DELAY *= 0.99;
  if (!currentBlock.canExist()) {
    println("Game over! Your score was", score);
    resetBoard();
    generateBlock();
    DELAY = 60;
    score = 0;
  }
}

void setup() {
  size(size*16, size*26);
  rectMode(CORNERS);
  
  resetBoard();
  generateBlock();
  
  minim = new Minim(this);
  println("Loading...");
  theme = minim.loadFile("themeA.mp3", 2048);
  AudioOutput out = minim.getLineOut();
  out.setGain(0.1);
  println("Loaded.");
  theme.loop();
  theme.play();
}

void draw() {
  if (!active) {
    background(bgcolor);
    fill(0);
    textFont(font);
    text("Press <ENTER> to unpause.", 8, size*13);
    return;
  }
  // Game clock
  timer -= 1;
  if (timer <= 0) {
    currentBlock.forceDown();
  }
  for (int i=flies.size()-1; i>-1; i--) {
    FBlock fly = flies.get(i);
    fly.iter();
    if (fly.y > size*30) {
      flies.remove(fly);
    }
  }
  
  render();
}

void render() {
  // Background rendering
  fill(bgcolor);
  background(bgcolor);
  // SBlock rendering
  for (int y=0; y<fieldh; y++) {
    for (int x=0; x<fieldw; x++) {
      if (sblock.shape[y][x]) {
        fill(sblock.colors[y][x]);
        trect(x, y, x+1, y+1);
      }
    }
  }
  // TBlock rendering
  fill(currentBlock.fill);
  for (int y=0; y<currentBlock.shape.length; y++) {
    for (int x=0; x<currentBlock.shape[y].length; x++) {
      if (currentBlock.shape[y][x]) {
        trect(currentBlock.px+x, currentBlock.py+y, currentBlock.px+x+1, currentBlock.py+y+1);
      }
    }
  }
  // Score rendering
  fill(0);
  textFont(font);
  text("Score: " + str(score), 40, 470);
  // Fly rendering
  for (FBlock fly : flies) {
    fill(fly.fill);
    rect(fly.x, fly.y, fly.x+size, fly.y+size);
  }
}

void trect(int x1, int y1, int x2, int y2) {
  x1 = between(0, x1, fieldw); x2 = between(0, x2, fieldw);
  y1 = between(0, y1, fieldh); y2 = between(0, y2, fieldh);
  
  x1 *= size; x2 *= size;
  y1 *= size; y2 *= size;
  
  x1 += fieldx; x2 += fieldx;
  y1 += fieldy; y2 += fieldy;
  
  rect(x1, y1, x2, y2);
}

int between(int lower, int num, int upper) {
  return max(min(upper, num), lower);
}

boolean keyDown(int code) {
  return keysDown.contains(code);
}

void keyPressed() {
  keysDown.add(keyEvent.getKeyCode());
  
  if (active) {
    if (keyCode == LEFT && currentBlock.canMoveLeft()) {
      currentBlock.moveLeft();
    }
    if (keyCode == RIGHT && currentBlock.canMoveRight()) {
      currentBlock.moveRight();
    }
    if (keyCode == DOWN && currentBlock.canMoveDown()) {
      timer = DELAY;
      currentBlock.moveDown();
    }
    if (keyCode == UP && currentBlock.canRotateClockwise()) {
      currentBlock.rotateClockwise();
    }
    if (key == ' ') {
      currentBlock.dropDown();
    }
  }
  if (keyCode == ENTER) {
    if (active) {
      active = false;
      theme.pause();
    }
    else {
      active = true;
      theme.play();
    }
  }
}

void keyReleased() {
  keysDown.remove(keyEvent.getKeyCode());
}

