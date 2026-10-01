function airhockey()
  % Two-player air hockey for Octave.
  %   Player 1 (right side): arrow keys (up/down/left/right)
  %   Player 2 (left side) : W / A / S / D
  %   First to WIN_SCORE wins. After a game: R = rematch, M = menu, Esc = quit.
  % The welcome screen goes step by step: nickname P1, color P1, nickname P2, color P2.
  % Run with:  airhockey
  % Needs Octave 6+ (figure KeyPressFcn and KeyReleaseFcn).

  global keys keyq
  keys = new_keys();
  keyq = {};

  fig = figure('Name', 'Air Hockey', 'NumberTitle', 'off', 'MenuBar', 'none', ...
               'Color', [0.1 0.1 0.15], ...
               'KeyPressFcn', @on_key_press, 'KeyReleaseFcn', @on_key_release);

  while ishghandle(fig)
    setup = welcome(fig);                    % [] means the player quit
    if isempty(setup) || ~ishghandle(fig), break; end
    result = play_game(fig, setup);          % 'menu' or 'quit'
    if ~strcmp(result, 'menu'), break; end
  end

  if ishghandle(fig), close(fig); end
  clear global keys keyq
end

% =====================================================================
%  WELCOME SCREEN
%  Stages: 1 = P1 nickname, 2 = P1 color, 3 = P2 nickname, 4 = P2 color
%  Enter moves to the next stage. In a color stage press 1-8, Space or
%  Left/Right to choose. This only relies on typed characters, so it
%  works even if the arrow/Tab key names differ between Octave versions.
% =====================================================================
function setup = welcome(fig)
  global keyq
  keyq = {};
  setup = [];

  bg = [0.1 0.1 0.15];
  palette = [0.90 0.30 0.30;    % 1 Red
             0.20 0.50 0.95;    % 2 Blue
             0.25 0.75 0.35;    % 3 Green
             1.00 0.60 0.15;    % 4 Orange
             0.60 0.35 0.85;    % 5 Purple
             0.95 0.85 0.20;    % 6 Yellow
             0.20 0.80 0.85;    % 7 Cyan
             0.95 0.45 0.70];   % 8 Pink
  cname = {'Red', 'Blue', 'Green', 'Orange', 'Purple', 'Yellow', 'Cyan', 'Pink'};
  nC = size(palette, 1);
  maxLen = 10;

  col = [2 1];                  % color index: P1 = Blue, P2 = Red
  nick = {'', ''};
  stage = 1;
  panelX = [1.5, 0.5];          % P1 on the right, P2 on the left (like the table)
  label = {'PLAYER 1   (arrow keys in game)', 'PLAYER 2   (W A S D in game)'};
  helpTxt = {'Player 1: type your nickname, then press Enter', ...
             'Player 1: press 1-8 (or Space / Left / Right) to pick a color, then Enter', ...
             'Player 2: type your nickname, then press Enter', ...
             'Player 2: press 1-8 (or Space / Left / Right) to pick a color, then Enter to start'};

  ax = axes('Parent', fig, 'Position', [0 0 1 1]);
  hold(ax, 'on');
  axis(ax, [0 2 0 1]); axis(ax, 'equal'); axis(ax, 'off');
  set(ax, 'Color', bg);

  text(1, 0.91, 'AIR HOCKEY', 'HorizontalAlignment', 'center', 'FontSize', 36, ...
       'FontWeight', 'bold', 'Color', 'w');
  hHelp = text(1, 0.81, '', 'HorizontalAlignment', 'center', 'FontSize', 13, ...
               'Color', [1 0.9 0.3], 'FontWeight', 'bold');
  text(1, 0.04, 'Enter: next step    Esc: quit', ...
       'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.8 0.8 0.9]);

  hPanel = zeros(1, 2); hNick = zeros(1, 2); hCname = zeros(1, 2);
  hSw = zeros(2, nC);
  for p = 1:2
    cx = panelX(p);
    hPanel(p) = rectangle('Position', [cx - 0.45, 0.10, 0.9, 0.62], ...
                          'FaceColor', [0.16 0.17 0.24], 'EdgeColor', [0.4 0.4 0.5], 'LineWidth', 3);
    text(cx, 0.67, label{p}, 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.8 0.8 0.9]);
    rectangle('Position', [cx - 0.35, 0.52, 0.7, 0.09], ...
              'FaceColor', [0.08 0.08 0.12], 'EdgeColor', [0.5 0.5 0.6]);
    hNick(p) = text(cx, 0.565, '', 'HorizontalAlignment', 'center', ...
                    'FontSize', 20, 'FontWeight', 'bold');
    for i = 1:nC
      r = ceil(i / 4); c = mod(i - 1, 4) + 1;
      x = cx - 0.34 + (c - 1) * 0.18;
      y = 0.36 - (r - 1) * 0.16;
      hSw(p, i) = rectangle('Position', [x, y, 0.14, 0.14], 'FaceColor', palette(i, :), ...
                            'EdgeColor', [0.3 0.3 0.4], 'LineWidth', 2);
      text(x + 0.07, y + 0.07, sprintf('%d', i), 'HorizontalAlignment', 'center', ...
           'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.05 0.05 0.1]);
    end
    hCname(p) = text(cx, 0.14, '', 'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', 'w');
  end

  t0 = tic;
  while ishghandle(fig)
    active = 1 + (stage >= 3);            % which player is being edited
    other = 3 - active;
    isNickStage = (mod(stage, 2) == 1);

    % --- handle queued key presses ---
    while ~isempty(keyq)
      ev = keyq{1}; keyq(1) = [];
      key = ev{1}; ch = ev{2};
      if ~ischar(ch), ch = ''; end
      code = -1;
      if numel(ch) == 1, code = double(ch); end

      isEsc   = strcmp(key, 'escape') || code == 27;
      isEnter = any(strcmp(key, {'return', 'enter'})) || code == 10 || code == 13;
      isBack  = strcmp(key, 'backspace') || code == 8 || code == 127;
      isLeft  = any(strcmp(key, {'leftarrow', 'left'}));
      isRight = any(strcmp(key, {'rightarrow', 'right'}));

      if isEsc
        if ishghandle(ax), delete(ax); end
        setup = [];
        return;
      elseif isEnter
        if stage < 4
          stage = stage + 1;
        else
          names = cell(1, 2);
          for p = 1:2
            names{p} = strtrim(nick{p});
            if isempty(names{p}), names{p} = sprintf('Player %d', p); end
          end
          setup = struct('names', {names}, 'colors', palette(col, :));
          if ishghandle(ax), delete(ax); end
          return;
        end
        active = 1 + (stage >= 3);
        other = 3 - active;
        isNickStage = (mod(stage, 2) == 1);
      elseif isNickStage
        if isBack
          if ~isempty(nick{active}), nick{active}(end) = []; end
        elseif code >= 32 && code < 127 && numel(nick{active}) < maxLen
          nick{active}(end + 1) = ch;
        end
      else
        % color stage
        if isLeft
          col(active) = next_color(col(active), -1, col(other), nC);
        elseif isRight || code == 32
          col(active) = next_color(col(active), +1, col(other), nC);
        elseif code >= double('1') && code <= double('0') + nC
          pick = code - double('0');
          if pick ~= col(other), col(active) = pick; end
        end
      end
    end

    % --- redraw ---
    set(hHelp, 'String', helpTxt{stage});
    blink = mod(floor(toc(t0) * 2), 2) == 0;
    for p = 1:2
      c = col(p);
      txt = nick{p};
      tcol = palette(c, :);
      if p == active
        set(hPanel(p), 'EdgeColor', [1 0.9 0.3]);
        if isNickStage
          if blink, txt = [txt '_']; else txt = [txt ' ']; end
        end
      else
        set(hPanel(p), 'EdgeColor', [0.4 0.4 0.5]);
        if isempty(txt), txt = sprintf('Player %d', p); tcol = [0.5 0.5 0.55]; end
      end
      set(hNick(p), 'String', txt, 'Color', tcol);
      for i = 1:nC
        if i == c
          set(hSw(p, i), 'EdgeColor', [1 1 1], 'LineWidth', 4);
        else
          set(hSw(p, i), 'EdgeColor', [0.3 0.3 0.4], 'LineWidth', 2);
        end
      end
      set(hCname(p), 'String', cname{c});
    end
    drawnow;
    pause(0.02);
  end
  setup = [];
end

function c = next_color(c, step, other, n)
  % Cycle to the next color, skipping the one the other player has.
  c = mod(c - 1 + step, n) + 1;
  if c == other
    c = mod(c - 1 + step, n) + 1;
  end
end

% =====================================================================
%  GAME
% =====================================================================
function result = play_game(fig, setup)
  global keys keyq
  keys = new_keys();
  keyq = {};
  result = 'quit';

  nm = setup.names;             % nm{1} = P1 (right), nm{2} = P2 (left)
  colP = setup.colors;          % row 1 = P1 color, row 2 = P2 color

  % ---- constants ----
  W = 2; H = 1;            % table size
  goalH = 0.4;             % goal opening height
  rp = 0.07;               % paddle radius
  ru = 0.05;               % puck radius
  % Paddle index 1 = P1 (right, arrows), 2 = P2 (left, WASD).
  xMin = [W/2 + rp, 0.10];
  xMax = [W - 0.10, W/2 - rp];
  xHome = [W - 0.20, 0.20];
  padSpeed = 1.3;
  maxPuck = 3.0;
  WIN_SCORE = 3;

  % ---- drawing ----
  ax = axes('Parent', fig, 'Position', [0.03 0.03 0.94 0.80]);
  hold(ax, 'on');
  axis(ax, [-0.1 W + 0.1 -0.05 H + 0.05]);
  axis(ax, 'equal'); axis(ax, 'off');
  set(ax, 'Color', [0.1 0.1 0.15]);

  rectangle('Position', [0 0 W H], 'FaceColor', [0.85 0.93 1.0], 'EdgeColor', [0.3 0.3 0.4], 'LineWidth', 3);
  line([W/2 W/2], [0 H], 'Color', [0.6 0.7 0.9], 'LineWidth', 2);
  rectangle('Position', [W/2 - 0.2, H/2 - 0.2, 0.4, 0.4], 'Curvature', [1 1], ...
            'EdgeColor', [0.6 0.7 0.9], 'LineWidth', 2);
  % goals (thick lines in each player's color)
  line([0 0], [H/2 - goalH/2, H/2 + goalH/2], 'Color', colP(2, :), 'LineWidth', 8);
  line([W W], [H/2 - goalH/2, H/2 + goalH/2], 'Color', colP(1, :), 'LineWidth', 8);

  hP2 = rectangle('Position', [0 0 2*rp 2*rp], 'Curvature', [1 1], ...
                  'FaceColor', colP(2, :), 'EdgeColor', [0.2 0.2 0.25], 'LineWidth', 2);
  hP1 = rectangle('Position', [0 0 2*rp 2*rp], 'Curvature', [1 1], ...
                  'FaceColor', colP(1, :), 'EdgeColor', [0.2 0.2 0.25], 'LineWidth', 2);
  hU  = rectangle('Position', [0 0 2*ru 2*ru], 'Curvature', [1 1], 'FaceColor', [0.1 0.1 0.1]);

  % scoreboard: P2 name (left), score (center), P1 name (right)
  text(0, H + 0.04, nm{2}, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
       'FontSize', 20, 'FontWeight', 'bold', 'Color', colP(2, :));
  text(W, H + 0.04, nm{1}, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
       'FontSize', 20, 'FontWeight', 'bold', 'Color', colP(1, :));
  hScore = text(W/2, H + 0.04, '', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 24, 'FontWeight', 'bold', 'Color', 'w');
  hMsg = text(W/2, H/2, '', 'HorizontalAlignment', 'center', 'FontSize', 18, ...
              'FontWeight', 'bold', 'Color', [0.1 0.1 0.15], 'BackgroundColor', [1 1 0.6]);
  text(W/2, -0.03, sprintf('%s: W A S D        %s: Arrow keys', nm{2}, nm{1}), ...
       'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 11, ...
       'Color', [0.8 0.8 0.9]);

  % ---- game state ----
  score = [0 0];                 % [P1 (right), P2 (left)]
  pad = [xHome(1), H/2; xHome(2), H/2];   % rows: [x y] for P1, P2
  [puck, vel] = serve(W, H, 0);
  freeze = 1.0;                  % short pause before play
  gameOver = false;
  set(hMsg, 'String', 'Get ready!');

  tprev = 0; t0 = tic;
  while ishghandle(fig)
    tnow = toc(t0);
    dt = min(tnow - tprev, 0.03);
    tprev = tnow;

    if keys.esc
      result = 'quit';
      break;
    end

    if gameOver
      if keys.r
        score = [0 0]; gameOver = false;
        [puck, vel] = serve(W, H, 0);
        freeze = 1.0;
        set(hMsg, 'String', 'Get ready!');
      elseif keys.m
        result = 'menu';
        break;
      end
    elseif freeze > 0
      freeze = freeze - dt;
      if freeze <= 0
        set(hMsg, 'String', '');
      end
    else
      % --- paddle movement ---
      dirs = [double(keys.right) - double(keys.left), double(keys.up) - double(keys.down); ...
              double(keys.d)     - double(keys.a),    double(keys.w) - double(keys.s)];
      pv = zeros(2, 2);
      for i = 1:2
        n = norm(dirs(i, :));
        if n > 0, pv(i, :) = dirs(i, :) / n * padSpeed; end   % no faster diagonals
      end
      pad = pad + pv * dt;
      pad(:, 1) = min(max(pad(:, 1), xMin(:)), xMax(:));
      pad(:, 2) = min(max(pad(:, 2), rp), H - rp);

      % --- puck movement ---
      puck = puck + vel * dt;
      vel = vel * (1 - 0.2 * dt);   % light friction

      % --- paddle collisions ---
      for i = 1:2
        pp = pad(i, :);
        dvec = puck - pp;
        dist = norm(dvec);
        if dist < rp + ru && dist > 0
          n = dvec / dist;
          puck = pp + n * (rp + ru);
          vrel = vel - pv(i, :);
          vn = dot(vrel, n);
          if vn < 0
            vel = vel - 2 * vn * n;
            vel = vel + 0.4 * n;       % small boost so rallies keep moving
          end
        end
      end

      % --- speed cap ---
      sp = norm(vel);
      if sp > maxPuck, vel = vel / sp * maxPuck; end

      % --- top/bottom walls ---
      if puck(2) < ru,     puck(2) = ru;     vel(2) =  abs(vel(2)); end
      if puck(2) > H - ru, puck(2) = H - ru; vel(2) = -abs(vel(2)); end

      % --- left/right walls and goals ---
      inGoal = abs(puck(2) - H/2) < goalH/2;
      scorer = 0;
      if inGoal
        if puck(1) < 0
          scorer = 1;                     % P1 scores in P2's goal (left)
        elseif puck(1) > W
          scorer = 2;                     % P2 scores in P1's goal (right)
        end
      else
        if puck(1) < ru,     puck(1) = ru;     vel(1) =  abs(vel(1)); end
        if puck(1) > W - ru, puck(1) = W - ru; vel(1) = -abs(vel(1)); end
      end

      if scorer > 0
        score(scorer) = score(scorer) + 1;
        if score(scorer) >= WIN_SCORE
          gameOver = true;
          set(hMsg, 'String', sprintf('%s wins!   R = rematch,  M = menu,  Esc = quit', nm{scorer}));
        else
          freeze = 1.2;
          set(hMsg, 'String', sprintf('%s scores!', nm{scorer}));
          [puck, vel] = serve(W, H, scorer);
        end
      end
    end

    % --- draw ---
    set(hP1, 'Position', [pad(1, 1) - rp, pad(1, 2) - rp, 2*rp, 2*rp]);
    set(hP2, 'Position', [pad(2, 1) - rp, pad(2, 2) - rp, 2*rp, 2*rp]);
    set(hU,  'Position', [puck(1) - ru, puck(2) - ru, 2*ru, 2*ru]);
    set(hScore, 'String', sprintf('%d  :  %d', score(2), score(1)));
    drawnow;
    pause(0.005);
  end

  if ishghandle(ax), delete(ax); end
end

% =====================================================================
%  HELPERS
% =====================================================================
function [puck, vel] = serve(W, H, scorer)
  % Puck starts at center and drifts toward the player who just conceded.
  puck = [W/2, H/2];
  if scorer == 1       % P1 scored, so serve toward the left (P2, who conceded)
    dirx = -1;
  elseif scorer == 2
    dirx = 1;
  else
    dirx = sign(rand - 0.5); if dirx == 0, dirx = 1; end
  end
  vel = [dirx * 0.6, (rand - 0.5) * 0.6];
end

function k = new_keys()
  k = struct('up', false, 'down', false, 'left', false, 'right', false, ...
             'w', false, 'a', false, 's', false, 'd', false, ...
             'r', false, 'm', false, 'esc', false);
end

function on_key_press(~, evt)
  global keys keyq
  try
    keys = set_key(keys, evt.Key, true);
  catch
  end
  ch = '';
  try
    if isfield(evt, 'Character'), ch = evt.Character; end
  catch
  end
  key = '';
  try
    key = lower(evt.Key);
  catch
  end
  if numel(keyq) < 50                      % queue is used by the welcome screen
    keyq{end + 1} = {key, ch};
  end
end

function on_key_release(~, evt)
  global keys
  try
    keys = set_key(keys, evt.Key, false);
  catch
  end
end

function k = set_key(k, name, val)
  switch lower(name)
    case {'uparrow', 'up'},       k.up = val;
    case {'downarrow', 'down'},   k.down = val;
    case {'leftarrow', 'left'},   k.left = val;
    case {'rightarrow', 'right'}, k.right = val;
    case 'w',                     k.w = val;
    case 'a',                     k.a = val;
    case 's',                     k.s = val;
    case 'd',                     k.d = val;
    case 'r',                     k.r = val;
    case 'm',                     k.m = val;
    case 'escape',                k.esc = val;
  end
end
