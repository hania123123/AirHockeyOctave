function airhockey_VF()
  %  AIR HOCKEY  -  airhockey_VF.m
  %  VERSION / ENVIRONMENT
  %    Code version : VF (final version 1.0)
  %    Octave       : 9.2.0
  %    Run with     : airhockey_VF
  %
  %  AUTHORS - all authors contributed equally: game physics (puck, paddles, collisions), computer opponent and difficulty levels, menu pages (start, difficulty, nickname, colors), pause / end pages, testing, comments, GitHub
  %    Student 1 : Nina Forster
  %    Student 2 : Zuzanna Kaczmarska
  %    Student 3 : Hanna Gembalczyk
  %
  %  DATE
  %    08/10/2026   (format: DD/MM/YYYY,)
  %
  %  SOURCES (AI / sound / image / word list)
  %    AI    : the computer opponent is a simple rule-based "AI" (function ai_move), It is NOT a trained / learning model.
  %    Sound : none.
  %    Image : none (everything is drawn with Octave rectangle / line / text).
  %    Word list : none.
  %
  %  CONTEXT OF THIS GAME
  %    Air hockey is a table game where two players hit a puck with paddles and try to shoot it into the opponent's goal. Here a human player plays against the computer, in a figure window, in real time.
  %
  %  GOAL
  %    Score 10 points (WIN_SCORE) before the computer does.
  %
  %  GAME COMPONENTS
  %    - table (2 x 1 units) with a center line, center circle, 2 goals
  %    - 2 paddles : computer (left, index 1) and player (right, index 2)
  %    - 1 puck
  %    - scoreboard (names, colors, score) and message text (countdown, goal)
  %    - menu pages: start, difficulty, nickname + color, pause, end
  %
  %  RULES
  %    - Hit the puck into the computer's goal (left side).
  %    - Your paddle stays on your half of the table (right side).
  %    - Every goal is worth 1 point. First to 10 points wins.
  %    - After a goal the puck is served toward the player who conceded.
  %    - A 3 s countdown starts the game and also follows every resume.
  %
  %  WAYS TO MOVE / CONTROLS
  %    - Arrow keys : move your paddle (diagonals are not faster)
  %    - Space      : pause page (Resume / Restart)
  %    - Esc        : quit
  %    - Mouse      : click buttons and colors in the menus
  %    - Keyboard   : type your nickname (max 10 characters)
  %
  %  MAIN VARIABLES
  %    keyState        struct of booleans, true while a key is held down
  %    keyQueue        cell array of one-shot key events (used by menus, pause)
  %    clickedButtonId number of the last clicked button (0 = none)
  %    setup           struct from the menus: names, colors, aiSpeed
  %    paddlePos       2x2 matrix, row = [x y] of computer / player
  %    paddleVel       2x2 matrix, row = [vx vy] of computer / player
  %    puckPos, puckVel position and velocity of the puck
  %    score           [computer player]
  %    countdown, freezeTime  timers in seconds (start / after a goal)
  %
  %  MAIN LOOP (detailed)
  %    airhockey_VF   : creates the figure, then repeats
  %                       welcome()   -> menu pages, returns the setup
  %                       play_game() -> one full game, returns 'menu' / 'quit'
  %    play_game, every frame (the speed is measured with tic / toc, so the game runs in real time and does not depend on computer speed):
  %       1. measure the time step dt (capped at 0.03 s)
  %       2. Esc -> quit; Space -> pause page
  %       3. countdown running -> show 3, 2, 1 and wait
  %       4. freeze after a goal -> wait 1.2 s
  %       5. otherwise: move computer paddle (ai_move) and your paddle,
  %          move the puck (light friction), paddle collisions, speed cap,
  %          wall bounces, goal detection and score update
  %       6. draw paddles, puck and score, then drawnow
  %       7. if a player reached 10 -> end page
  %
  %  ACROSS TRIALS (games)
  %    Each game starts at 0 : 0. "Play again" (end page) or "Restart"
  %    (pause page) goes back to the start page, where difficulty, nickname and color can be chosen again. Nothing is kept between games.
  % =====================================================================

  global keyState keyQueue clickedButtonId

  % initial state of the global variables
  keyState = new_key_state();
  keyQueue = {};
  clickedButtonId = 0;

  % main window (dark background, keyboard callbacks)
  mainFigure = figure('Name', 'Air Hockey', 'NumberTitle', 'off', 'MenuBar', 'none', ...
                      'Color', [0.1 0.1 0.15], ...
                      'KeyPressFcn', @on_key_press, 'KeyReleaseFcn', @on_key_release);

  % menus -> game -> menus ... until the player quits
  while ishghandle(mainFigure)
    setup = welcome(mainFigure);
    if isempty(setup) || ~ishghandle(mainFigure), break; end
    result = play_game(mainFigure, setup);          % 'menu' or 'quit'
    if ~strcmp(result, 'menu'), break; end
  end

  % clean up
  if ishghandle(mainFigure), close(mainFigure); end
  clear global keyState keyQueue clickedButtonId
endfunction

% =====================================================================
%  WELCOME SCREENS
%  Stage 1 = start page (title, goal, rules, controls, PLAY button - click it)
%  Stage 2 = difficulty (click a level name to select it and continue)
%  Stage 3 = nickname (type), paddle color (click a color), PLAY button (click it)
%  The computer (left side) is always called "Computer" and gets an
%  automatic color that differs from yours.
% =====================================================================
function setup = welcome(mainFigure)
  global keyQueue clickedButtonId
  keyQueue = {};
  clickedButtonId = 0;
  setup = [];

  % ---- colors, difficulty levels and menu state ----
  backgroundColor = [0.1 0.1 0.15];
  palette = [0.90 0.30 0.30;    % 1 Red
             0.20 0.50 0.95;    % 2 Blue
             0.25 0.75 0.35;    % 3 Green
             1.00 0.60 0.15;    % 4 Orange
             0.60 0.35 0.85;    % 5 Purple
             0.95 0.85 0.20;    % 6 Yellow
             0.20 0.80 0.85;    % 7 Cyan
             0.95 0.45 0.70];   % 8 Pink
  colorNames = {'Red', 'Blue', 'Green', 'Orange', 'Purple', 'Yellow', 'Cyan', 'Pink'};
  nbColors = size(palette, 1);
  maxNicknameLength = 10;

  difficultyNames = {'Beginner', 'Normal', 'Advanced'};
  difficultySpeeds = [0.10 0.30 0.50];    % computer speed per level
  difficultyLevel = 2;                    % selected difficulty (set by clicking a level)

  colorIndex = [1 2];                     % color index: [computer, player]
  nickname = '';
  stage = 1;                              % 1 = start page, 2 = difficulty, 3 = nickname + color

  % ---- drawing area for the menu pages ----
  menuAxes = axes('Parent', mainFigure, 'Position', [0 0 1 1]);
  hold(menuAxes, 'on');
  axis(menuAxes, [0 2 0 1]); axis(menuAxes, 'equal'); axis(menuAxes, 'off');
  set(menuAxes, 'Color', backgroundColor);

  text(1, 0.93, 'AIR HOCKEY', 'HorizontalAlignment', 'center', 'FontSize', 32, ...
       'FontWeight', 'bold', 'Color', 'w');

  % ---------- stage 1: start page ----------
  hStartPage = [];
  hStartPage(end + 1) = text(1, 0.81, 'GOAL: score 10 points before the computer does.', ...
      'HorizontalAlignment', 'center', 'FontSize', 25, 'FontWeight', 'bold', 'Color', [1 0.9 0.3]);
  hStartPage(end + 1) = text(1, 0.72, 'RULES', 'HorizontalAlignment', 'center', ...
      'FontSize', 12, 'FontWeight', 'bold', 'Color', [1 0.9 0.3]);
  hStartPage(end + 1) = text(1, 0.66, 'Hit the puck into the computer''s goal (left side).', ...
      'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', [0.85 0.85 0.95]);
  hStartPage(end + 1) = text(1, 0.60, 'Your paddle stays on your half of the table (right side).', ...
      'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', [0.85 0.85 0.95]);
  hStartPage(end + 1) = text(1, 0.54, 'Every goal is worth 1 point. First to score 10 points wins.', ...
      'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', [0.85 0.85 0.95]);
  hStartPage(end + 1) = text(1, 0.48, 'After a goal the puck is served toward the player who conceded.', ...
      'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', [0.85 0.85 0.95]);
  hStartPage(end + 1) = text(1, 0.39, 'CONTROLS', 'HorizontalAlignment', 'center', ...
      'FontSize', 12, 'FontWeight', 'bold', 'Color', [1 0.9 0.3]);
  hStartPage(end + 1) = text(1, 0.33, 'Arrow keys: move your paddle', ...
      'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', [0.85 0.85 0.95]);
  hStartPage(end + 1) = text(1, 0.27, 'Space: pause          Esc: quit', ...
      'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', [0.85 0.85 0.95]);
  hStartButton = make_button([0.75, 0.06, 0.5, 0.13], 'PLAY', 18, 1);
  hStartPage = [hStartPage hStartButton];

  % ---------- stage 2: difficulty ----------
  hDifficultyPage = [];
  hDifficultyPage(end + 1) = text(1, 0.83, 'SELECT DIFFICULTY LEVEL  (click a level)', ...
      'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold', 'Color', [1 0.9 0.3]);
  hDifficultyPage(end + 1) = rectangle('Position', [0.45, 0.08, 1.1, 0.66], ...
      'FaceColor', [0.16 0.17 0.24], 'EdgeColor', [0.4 0.4 0.5], 'LineWidth', 3);
  hDifficultyButtons = cell(1, 3);
  for levelNumber = 1:3
    hDifficultyButtons{levelNumber} = make_button( ...
        [0.7, 0.54 - (levelNumber - 1) * 0.17, 0.6, 0.12], ...
        upper(difficultyNames{levelNumber}), 16, 10 + levelNumber);
    hDifficultyPage = [hDifficultyPage hDifficultyButtons{levelNumber}];
  end
  hDifficultyPage(end + 1) = text(1, 0.03, 'Click a level to select it and continue', ...
      'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.8 0.8 0.9]);

  % ---------- stage 3: nickname + color + PLAY ----------
  hSetupPage = [];
  hSetupPage(end + 1) = text(1, 0.83, 'CHOOSE YOUR NICKNAME AND PADDLE COLOR', ...
      'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold', 'Color', [1 0.9 0.3]);
  hSetupPage(end + 1) = rectangle('Position', [0.45, 0.08, 1.1, 0.66], ...
      'FaceColor', [0.16 0.17 0.24], 'EdgeColor', [0.4 0.4 0.5], 'LineWidth', 3);
  hSetupPage(end + 1) = text(1, 0.685, 'NICKNAME  (type)', 'HorizontalAlignment', 'center', ...
      'FontSize', 11, 'Color', [0.8 0.8 0.9]);
  hSetupPage(end + 1) = rectangle('Position', [0.7, 0.555, 0.6, 0.08], ...
      'FaceColor', [0.08 0.08 0.12], 'EdgeColor', [1 0.9 0.3], 'LineWidth', 2);
  hNickname = text(1, 0.595, '', 'HorizontalAlignment', 'center', 'FontSize', 20, 'FontWeight', 'bold');
  hSetupPage(end + 1) = hNickname;
  hSetupPage(end + 1) = text(1, 0.48, 'COLOR  (click a color)', 'HorizontalAlignment', 'center', ...
      'FontSize', 11, 'Color', [0.8 0.8 0.9]);
  hSwatches = zeros(1, nbColors);
  for colorNumber = 1:nbColors
    swatchX = 0.495 + (colorNumber - 1) * 0.13;
    hSwatches(colorNumber) = rectangle('Position', [swatchX, 0.34, 0.10, 0.10], ...
                       'FaceColor', palette(colorNumber, :), ...
                       'EdgeColor', [0.3 0.3 0.4], 'LineWidth', 2, ...
                       'ButtonDownFcn', @(~, ~) set_click(30 + colorNumber));
    hSetupPage(end + 1) = hSwatches(colorNumber);
  end
  hColorName = text(1, 0.29, '', 'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', 'w');
  hSetupPage(end + 1) = hColorName;
  hPlayButton = make_button([0.75, 0.10, 0.5, 0.12], 'PLAY', 18, 40);
  hSetupPage = [hSetupPage hPlayButton];
  hSetupPage(end + 1) = text(1, 0.03, 'Type your nickname    Click a color    Click PLAY to start', ...
      'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.8 0.8 0.9]);

  % ---- menu loop ----
  shownStage = 0;
  menuTimer = tic;
  while ishghandle(mainFigure)
    startGame = false;

    % --- mouse clicks on buttons ---
    if clickedButtonId ~= 0
      buttonId = clickedButtonId;
      clickedButtonId = 0;
      if stage == 1 && buttonId == 1
        stage = 2;
      elseif stage == 2
        if buttonId >= 11 && buttonId <= 13
          difficultyLevel = buttonId - 10;
          stage = 3;
        end
      elseif stage == 3
        if buttonId >= 31 && buttonId <= 30 + nbColors
          colorIndex(2) = buttonId - 30;
        elseif buttonId == 40
          startGame = true;
        end
      end
    end

    % --- handle queued key presses ---
    while ~isempty(keyQueue)
      keyEvent = keyQueue{1}; keyQueue(1) = [];
      keyName = keyEvent{1}; character = keyEvent{2};
      if ~ischar(character), character = ''; end
      charCode = -1;
      if numel(character) == 1, charCode = double(character); end

      isEscape    = strcmp(keyName, 'escape') || charCode == 27;
      isBackspace = strcmp(keyName, 'backspace') || charCode == 8 || charCode == 127;

      if isEscape
        if ishghandle(menuAxes), delete(menuAxes); end
        setup = [];
        return;
      elseif stage == 3
        if isBackspace
          if ~isempty(nickname), nickname(end) = []; end
        elseif charCode >= 32 && charCode < 127 && numel(nickname) < maxNicknameLength
          nickname(end + 1) = character;
        end
      endif
    end

    % --- start the game: build the setup struct and leave the menus ---
    if startGame
      playerName = strtrim(nickname);
      if isempty(playerName), playerName = 'Player'; end
      % computer takes a color different from players
      if colorIndex(2) == 1, colorIndex(1) = 2; else colorIndex(1) = 1; end
      setup = struct('names', {{'Computer', playerName}}, 'colors', palette(colorIndex, :), ...
                     'aiSpeed', difficultySpeeds(difficultyLevel));
      if ishghandle(menuAxes), delete(menuAxes); end
      return;
    end

    % --- redraw: show only the objects of the current stage ---
    blink = mod(floor(toc(menuTimer) * 2), 2) == 0;
    if stage ~= shownStage
      set(hStartPage, 'Visible', 'off');
      set(hDifficultyPage, 'Visible', 'off');
      set(hSetupPage, 'Visible', 'off');
      switch stage
        case 1, set(hStartPage, 'Visible', 'on');
        case 2, set(hDifficultyPage, 'Visible', 'on');
        case 3, set(hSetupPage, 'Visible', 'on');
      end
      shownStage = stage;
    end

    if stage == 1
      % blinking border on the PLAY button
      if blink
        set(hStartButton(1), 'EdgeColor', [1 1 1]);
      else
        set(hStartButton(1), 'EdgeColor', [0.6 0.5 0.1]);
      end
    elseif stage == 2
      for levelNumber = 1:3
        set(hDifficultyButtons{levelNumber}(1), 'FaceColor', [1 0.9 0.3], 'EdgeColor', [1 1 1]);
        set(hDifficultyButtons{levelNumber}(2), 'Color', [0.1 0.1 0.15]);
      end
    else
      % nickname with blinking cursor, highlighted selected color
      nicknameText = nickname;
      if blink, nicknameText = [nicknameText '_']; else nicknameText = [nicknameText ' ']; end
      set(hNickname, 'String', nicknameText, 'Color', palette(colorIndex(2), :));
      for colorNumber = 1:nbColors
        if colorNumber == colorIndex(2)
          set(hSwatches(colorNumber), 'EdgeColor', [1 1 1], 'LineWidth', 4);
        else
          set(hSwatches(colorNumber), 'EdgeColor', [0.3 0.3 0.4], 'LineWidth', 2);
        end
      end
      set(hColorName, 'String', colorNames{colorIndex(2)});
    end
    drawnow;
    pause(0.02);
  end
  setup = [];
endfunction

% =====================================================================
%  GAME
% =====================================================================
function result = play_game(mainFigure, setup)
  global keyState keyQueue
  keyState = new_key_state();
  keyQueue = {};
  result = 'quit';

  playerNames = setup.names;    % playerNames{1} = Computer (left), playerNames{2} = player (right)
  playerColors = setup.colors;  % row 1 = computer color, row 2 = player color

  % ---- constants ----
  tableWidth = 2; tableHeight = 1;   % table size
  goalHeight = 0.4;                  % goal opening height
  paddleRadius = 0.07;
  puckRadius = 0.05;
  % Paddle index 1 = computer (left), 2 = player (right, arrow keys).
  paddleXMin = [0.10, tableWidth/2 + paddleRadius];
  paddleXMax = [tableWidth/2 - paddleRadius, tableWidth - 0.10];
  paddleHomeX = [0.20, tableWidth - 0.20];
  playerPaddleSpeed = 1.3;
  computerPaddleSpeed = setup.aiSpeed;
  maxPuckSpeed = 3.0;
  WIN_SCORE = 10;

  % ---- drawing: table, goals, paddles, puck, texts ----
  gameAxes = axes('Parent', mainFigure, 'Position', [0.03 0.03 0.94 0.80]);
  hold(gameAxes, 'on');
  axis(gameAxes, [-0.1 tableWidth + 0.1 -0.05 tableHeight + 0.05]);
  axis(gameAxes, 'equal'); axis(gameAxes, 'off');
  set(gameAxes, 'Color', [0.1 0.1 0.15]);

  rectangle('Position', [0 0 tableWidth tableHeight], 'FaceColor', [0.85 0.93 1.0], ...
            'EdgeColor', [0.3 0.3 0.4], 'LineWidth', 3);
  line([tableWidth/2 tableWidth/2], [0 tableHeight], 'Color', [0.6 0.7 0.9], 'LineWidth', 2);
  rectangle('Position', [tableWidth/2 - 0.2, tableHeight/2 - 0.2, 0.4, 0.4], 'Curvature', [1 1], ...
            'EdgeColor', [0.6 0.7 0.9], 'LineWidth', 2);
  % goals (thick lines in each player's color)
  line([0 0], [tableHeight/2 - goalHeight/2, tableHeight/2 + goalHeight/2], ...
       'Color', playerColors(1, :), 'LineWidth', 8);
  line([tableWidth tableWidth], [tableHeight/2 - goalHeight/2, tableHeight/2 + goalHeight/2], ...
       'Color', playerColors(2, :), 'LineWidth', 8);

  hPaddlePlayer = rectangle('Position', [0 0 2*paddleRadius 2*paddleRadius], 'Curvature', [1 1], ...
                  'FaceColor', playerColors(2, :), 'EdgeColor', [0.2 0.2 0.25], 'LineWidth', 2);
  hPaddleComputer = rectangle('Position', [0 0 2*paddleRadius 2*paddleRadius], 'Curvature', [1 1], ...
                  'FaceColor', playerColors(1, :), 'EdgeColor', [0.2 0.2 0.25], 'LineWidth', 2);
  hPuck = rectangle('Position', [0 0 2*puckRadius 2*puckRadius], 'Curvature', [1 1], ...
                    'FaceColor', [0.1 0.1 0.1]);

  % scoreboard: computer name (left), score (center), player name (right)
  text(0, tableHeight + 0.04, playerNames{1}, 'HorizontalAlignment', 'left', ...
       'VerticalAlignment', 'bottom', 'FontSize', 20, 'FontWeight', 'bold', ...
       'Color', playerColors(1, :));
  text(tableWidth, tableHeight + 0.04, playerNames{2}, 'HorizontalAlignment', 'right', ...
       'VerticalAlignment', 'bottom', 'FontSize', 20, 'FontWeight', 'bold', ...
       'Color', playerColors(2, :));
  hScore = text(tableWidth/2, tableHeight + 0.04, '', 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', 'FontSize', 24, 'FontWeight', 'bold', 'Color', 'w');
  hMessage = text(tableWidth/2, tableHeight/2, '', 'HorizontalAlignment', 'center', 'FontSize', 18, ...
              'FontWeight', 'bold', 'Color', [0.1 0.1 0.15], 'BackgroundColor', [1 1 0.6]);
  text(tableWidth/2, -0.03, sprintf('%s: arrow keys    |    Space: pause', playerNames{2}), ...
       'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 11, ...
       'Color', [0.8 0.8 0.9]);

  % everything drawn on the table (hidden while a pause / end page is shown)
  hGameObjects = get(gameAxes, 'children');

  % ---- game state ----
  score = [0 0];                 % [computer (left), player (right)]
  paddlePos = [paddleHomeX(1), tableHeight/2; paddleHomeX(2), tableHeight/2];   % rows: [x y] computer, player
  [puckPos, puckVel] = serve(tableWidth, tableHeight, 0);
  paddleVel = zeros(2, 2);
  freezeTime = 0;                % short pause after a goal
  countdown = 3.0;               % 3 s countdown before play starts / resumes
  gameOver = false;
  winner = 0;

  % ---- main game loop (real time, measured with tic / toc) ----
  previousTime = 0; gameTimer = tic;
  while ishghandle(mainFigure)
    currentTime = toc(gameTimer);
    dt = min(currentTime - previousTime, 0.03);
    previousTime = currentTime;

    if keyState.esc
      result = 'quit';
      break;
    end

    % --- one-shot key events (Space = pause) ---
    pauseRequested = false;
    while ~isempty(keyQueue)
      keyEvent = keyQueue{1}; keyQueue(1) = [];
      keyName = keyEvent{1}; character = keyEvent{2};
      if ~ischar(character), character = ''; end
      charCode = -1;
      if numel(character) == 1, charCode = double(character); end
      isSpace = strcmp(keyName, 'space') || charCode == 32;
      if isSpace && countdown <= 0 && ~gameOver
        pauseRequested = true;
      end
    end

    % --- pause page (same style as the other pages, game is frozen meanwhile) ---
    if pauseRequested
      set(hGameObjects, 'Visible', 'off');
      choice = show_page(mainFigure, 'PAUSED', '', {'Resume', 'Restart'}, [1 0.9 0.3]);
      if ~ishghandle(mainFigure), break; end
      set(hGameObjects, 'Visible', 'on');
      keyState = new_key_state();
      keyQueue = {};
      if choice == 2                       % restart -> start page
        result = 'menu';
        break;
      elseif choice ~= 1                   % Esc
        result = 'quit';
        break;
      end
      countdown = 3.0;                     % resume with a new countdown
      set(hMessage, 'String', '');
      previousTime = toc(gameTimer);
      continue;
    end

    if countdown > 0
      countdown = countdown - dt;
      if countdown > 0
        set(hMessage, 'String', sprintf('%d', ceil(countdown)), 'FontSize', 40);
      else
        set(hMessage, 'String', '', 'FontSize', 18);
      end
    elseif freezeTime > 0
      % --- short freeze after a goal ---
      freezeTime = freezeTime - dt;
      if freezeTime <= 0
        set(hMessage, 'String', '');
      end
    else
      % --- paddle movement ---
      paddleVel = zeros(2, 2);
      % computer (paddle 1)
      paddleVel(1, :) = ai_move(paddlePos(1, :), puckPos, puckVel, tableWidth, tableHeight, ...
                                goalHeight, paddleHomeX(1)) * computerPaddleSpeed;
      % player (paddle 2): arrow keys
      moveDirection = [double(keyState.right) - double(keyState.left), ...
                       double(keyState.up) - double(keyState.down)];
      moveLength = norm(moveDirection);
      if moveLength > 0, paddleVel(2, :) = moveDirection / moveLength * playerPaddleSpeed; end
      paddlePos = paddlePos + paddleVel * dt;
      paddlePos(:, 1) = min(max(paddlePos(:, 1), paddleXMin(:)), paddleXMax(:));
      paddlePos(:, 2) = min(max(paddlePos(:, 2), paddleRadius), tableHeight - paddleRadius);

      % --- puck movement ---
      puckPos = puckPos + puckVel * dt;
      puckVel = puckVel * (1 - 0.2 * dt);   % light friction

      % --- paddle collisions ---
      for paddleNumber = 1:2
        currentPaddle = paddlePos(paddleNumber, :);
        offsetVector = puckPos - currentPaddle;
        distance = norm(offsetVector);
        if distance < paddleRadius + puckRadius && distance > 0
          normal = offsetVector / distance;
          puckPos = currentPaddle + normal * (paddleRadius + puckRadius);
          relativeVel = puckVel - paddleVel(paddleNumber, :);
          normalSpeed = dot(relativeVel, normal);
          if normalSpeed < 0
            puckVel = puckVel - 2 * normalSpeed * normal;
            puckVel = puckVel + 0.4 * normal;
          end
        end
      end

      % --- speed cap ---
      puckSpeed = norm(puckVel);
      if puckSpeed > maxPuckSpeed, puckVel = puckVel / puckSpeed * maxPuckSpeed; end

      % --- top/bottom walls ---
      if puckPos(2) < puckRadius
        puckPos(2) = puckRadius;
        puckVel(2) = abs(puckVel(2));
      end
      if puckPos(2) > tableHeight - puckRadius
        puckPos(2) = tableHeight - puckRadius;
        puckVel(2) = -abs(puckVel(2));
      end

      % --- left/right walls and goals ---
      inGoalZone = abs(puckPos(2) - tableHeight/2) < goalHeight/2;
      scorer = 0;
      if inGoalZone
        if puckPos(1) < 0
          scorer = 2;                     % player score in the computer's goal (left)
        elseif puckPos(1) > tableWidth
          scorer = 1;                     % computer scores in player goal (right)
        end
      else
        if puckPos(1) < puckRadius
          puckPos(1) = puckRadius;
          puckVel(1) = abs(puckVel(1));
        end
        if puckPos(1) > tableWidth - puckRadius
          puckPos(1) = tableWidth - puckRadius;
          puckVel(1) = -abs(puckVel(1));
        end
      end

      % --- goal scored: update score, end game or serve again ---
      if scorer > 0
        score(scorer) = score(scorer) + 1;
        if score(scorer) >= WIN_SCORE
          gameOver = true;
          winner = scorer;
          set(hMessage, 'String', '');
        else
          freezeTime = 1.2;
          set(hMessage, 'String', sprintf('%s scores!', playerNames{scorer}));
          [puckPos, puckVel] = serve(tableWidth, tableHeight, scorer);
        end
      end
    end

    % --- draw paddles, puck and score ---
    set(hPaddleComputer, 'Position', [paddlePos(1, 1) - paddleRadius, paddlePos(1, 2) - paddleRadius, ...
                                      2*paddleRadius, 2*paddleRadius]);
    set(hPaddlePlayer, 'Position', [paddlePos(2, 1) - paddleRadius, paddlePos(2, 2) - paddleRadius, ...
                                    2*paddleRadius, 2*paddleRadius]);
    set(hPuck, 'Position', [puckPos(1) - puckRadius, puckPos(2) - puckRadius, ...
                            2*puckRadius, 2*puckRadius]);
    set(hScore, 'String', sprintf('%d  :  %d', score(1), score(2)));
    drawnow;

    % --- end page (same style as the other pages) ---
    if gameOver
      set(hGameObjects, 'Visible', 'off');
      if winner == 2
        choice = show_page(mainFigure, sprintf('CONGRATULATIONS, %s!', playerNames{2}), ...
                           sprintf('You won  %d : %d', score(2), score(1)), ...
                           {'Play again'}, [0.4 1 0.5]);
      else
        choice = show_page(mainFigure, sprintf('You lost, %s!', playerNames{2}), ...
                           sprintf('Computer wins  %d : %d', score(1), score(2)), ...
                           {'Play again'}, [1 0.45 0.45]);
      end
      if ishghandle(mainFigure) && choice == 1
        result = 'menu';
      else
        result = 'quit';
      end
      break;
    end

    pause(0.005);
  end

  if ishghandle(gameAxes), delete(gameAxes); end
endfunction

% =====================================================================
%  HELPERS
% =====================================================================
function choice = show_page(mainFigure, titleText, subtitleText, buttonLabels, titleColor)
  % Full page in the figure (same look as the menu pages) with clickable buttons.
  global clickedButtonId keyState keyQueue
  clickedButtonId = 0;
  choice = 0;
  backgroundColor = [0.1 0.1 0.15];
  nbButtons = numel(buttonLabels);

  pageAxes = axes('Parent', mainFigure, 'Position', [0 0 1 1]);
  hold(pageAxes, 'on');
  axis(pageAxes, [0 2 0 1]); axis(pageAxes, 'equal'); axis(pageAxes, 'off');
  set(pageAxes, 'Color', backgroundColor);

  text(1, 0.93, 'AIR HOCKEY', 'HorizontalAlignment', 'center', 'FontSize', 40, ...
       'FontWeight', 'bold', 'Color', 'w');
  rectangle('Position', [0.45, 0.08, 1.1, 0.70], ...
            'FaceColor', [0.16 0.17 0.24], 'EdgeColor', [0.4 0.4 0.5], 'LineWidth', 3);
  text(1, 0.68, titleText, 'HorizontalAlignment', 'center', 'FontSize', 30, ...
       'FontWeight', 'bold', 'Color', titleColor);
  if ~isempty(subtitleText)
    text(1, 0.57, subtitleText, 'HorizontalAlignment', 'center', 'FontSize', 20, 'Color', 'w');
  end
  for buttonNumber = 1:nbButtons
    make_button([0.75, 0.40 - (buttonNumber - 1) * 0.15, 0.5, 0.11], ...
                buttonLabels{buttonNumber}, 22, buttonNumber);
  end
  text(1, 0.03, 'Click a button to continue    Esc: quit', ...
       'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.8 0.8 0.9]);

  % wait until a button is clicked, Esc is pressed or the window is closed
  while ishghandle(mainFigure) && choice == 0
    if keyState.esc
      choice = -1;
    elseif clickedButtonId ~= 0
      choice = clickedButtonId;
    end
    keyQueue = {};
    drawnow;
    pause(0.02);        % short rest between refreshes (polling, no waiting)
  end
  clickedButtonId = 0;
  if ishghandle(pageAxes), delete(pageAxes); end
endfunction

function handles = make_button(position, label, fontSize, buttonId)
  % Rounded button (rectangle + label). Returns [rectangle_handle text_handle].
  buttonRect = rectangle('Position', position, 'Curvature', [0.3 0.3], ...
                'FaceColor', [1 0.9 0.3], 'EdgeColor', [1 1 1], 'LineWidth', 3, ...
                'ButtonDownFcn', @(~, ~) set_click(buttonId));
  buttonText = text(position(1) + position(3) / 2, position(2) + position(4) / 2, label, ...
           'HorizontalAlignment', 'center', 'FontSize', fontSize, 'FontWeight', 'bold', ...
           'Color', [0.1 0.1 0.15], 'ButtonDownFcn', @(~, ~) set_click(buttonId));
  handles = [buttonRect buttonText];
endfunction

function set_click(buttonId)
  % Called by a button when it is clicked: remembers which one.
  global clickedButtonId
  clickedButtonId = buttonId;
endfunction

function moveDir = ai_move(paddlePosition, puckPosition, puckVelocity, tableWidth, tableHeight, goalHeight, homeX)
  % Returns the computer paddle's movement direction (length <= 1).
  % The computer plays on the LEFT side and shoots to the right.
  if puckPosition(1) < tableWidth/2 + 0.05
    % puck is on the computer's side: go attack it
    if paddlePosition(1) < puckPosition(1) - 0.02
      target = puckPosition + 0.1 * puckVelocity;   % in front of the puck: hit it right
    else
      % puck is behind the paddle: swing around it first
      side = sign(paddlePosition(2) - puckPosition(2));
      if side == 0, side = 1; end
      target = [puckPosition(1) - 0.15, puckPosition(2) + side * 0.2];
    end
  else
    % puck is on your side: guard the goal
    target = [homeX, min(max(puckPosition(2), tableHeight/2 - goalHeight/2), tableHeight/2 + goalHeight/2)];
  end
  toTarget = target - paddlePosition;
  distanceToTarget = norm(toTarget);
  if distanceToTarget < 0.01
    moveDir = [0 0];
  else
    moveDir = toTarget / distanceToTarget * min(1, distanceToTarget / 0.08);   % slow down near the target
  end
endfunction

function [puckPosition, puckVelocity] = serve(tableWidth, tableHeight, scorer)
  % Puck starts at center and drifts toward the player who just conceded.
  puckPosition = [tableWidth/2, tableHeight/2];
  if scorer == 1       % computer scored, so serve toward the right (player, who conceded)
    directionX = 1;
  elseif scorer == 2   % player scored, so serve toward the left (computer)
    directionX = -1;
  else
    directionX = sign(rand - 0.5); if directionX == 0, directionX = 1; end
  end
  puckVelocity = [directionX * 0.6, (rand - 0.5) * 0.6];
endfunction

function state = new_key_state()
  % Creates the key state struct: every key starts as "not pressed".
  state = struct('up', false, 'down', false, 'left', false, 'right', false, ...
                 'w', false, 'a', false, 's', false, 'd', false, ...
                 'r', false, 'm', false, 'esc', false);
endfunction

function on_key_press(~, eventData)
  % Figure callback: a key was pressed.
  global keyState keyQueue
  try
    keyState = set_key(keyState, eventData.Key, true);
  catch
  end_try_catch
  character = '';
  try
    if isfield(eventData, 'Character'), character = eventData.Character; end
  catch
  end_try_catch
  keyName = '';
  try
    keyName = lower(eventData.Key);
  catch
  end_try_catch
  if numel(keyQueue) < 50                      % queue is used by the menus
    keyQueue{end + 1} = {keyName, character};
  end
endfunction

function on_key_release(~, eventData)
  % Figure callback: a key was released.
  global keyState
  try
    keyState = set_key(keyState, eventData.Key, false);
  catch
  end_try_catch
endfunction

function state = set_key(state, keyName, isDown)
  % Sets one field of the key state struct to true / false.
  switch lower(keyName)
    case {'uparrow', 'up'},       state.up = isDown;
    case {'downarrow', 'down'},   state.down = isDown;
    case {'leftarrow', 'left'},   state.left = isDown;
    case {'rightarrow', 'right'}, state.right = isDown;
    case 'w',                     state.w = isDown;
    case 'a',                     state.a = isDown;
    case 's',                     state.s = isDown;
    case 'd',                     state.d = isDown;
    case 'r',                     state.r = isDown;
    case 'm',                     state.m = isDown;
    case 'escape',                state.esc = isDown;
  endswitch
endfunction
