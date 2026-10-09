function SpringDamperLab()
% SPRINGDAMPERLAB  Interactive "energy lab" for a spring and damper in parallel.
%
%   Wall --[ spring ]--+
%        --[ damper ]--+--> F(t)
%
%   Physics (massless rigid connector, 1-D):
%       F(t) = Fspring(x) + Fdamper(v)           (force balance)
%       Energy:  W (work by F) + U0 = U (spring stored) + D (damper dissipated)
%   Because the damper law is monotonic, we invert it to get v = g(F - Fs(x))
%   and solve the first-order ODE  dx/dt = g(F(t) - Fs(x)).
%   W, D are integrated alongside x so the energy books balance accurately.
%
%   To build an .exe:   mcc -m SpringDamperLab.m
%   (or MATLAB Apps tab > Application Compiler > Standalone Application)

% ------------------------------------------------------------------ setup
S = struct('t',[],'x',[],'W',[],'U',[],'D',[],'F',[],'Fs',[],'Fd',[],'Pd',[], ...
           'T',10,'tc',0,'scale',1,'Fmax',1,'playing',false,'ghost',[],'p',[]);
H = struct();

ftypes = {'Step (constant)','Exponential settle','Sine around offset', ...
          'Damped sine','Square wave','Pulse then release'};
stypes = {'Linear (F = kx)','Hardening (kx + k3 x^3)','Softening (k L tanh(x/L))'};
dtypes = {'Linear (F = b v)','Power-law (F = b|v|^n)'};

base = struct('ftype',ftypes{3},'F0',5,'A',3,'f',0.5,'tau',2, ...
              'stype',stypes{1},'k',10,'kshape',5, ...
              'dtype',dtypes{1},'b',5,'n',2,'x0',0,'T',12);
presetNames = {'Default: gentle sine pull', ...
               'Shock absorber (very high b)', ...
               'Drive at the corner frequency', ...
               'Let go! (stretched, no force)', ...
               'Hardening spring + quadratic damper', ...
               'Square-wave kicks', ...
               'Fading shake (damped sine)'};
P = cell(1,7);
P{1} = base;
P{2} = ovr(base,'b',60);
P{3} = ovr(base,'F0',0,'A',5,'f',base.k/(2*pi*base.b));
P{4} = ovr(base,'ftype',ftypes{1},'F0',0,'x0',1,'T',6);
P{5} = ovr(base,'ftype',ftypes{1},'F0',40,'stype',stypes{2},'kshape',20, ...
           'dtype',dtypes{2},'b',8,'n',2,'T',10);
P{6} = ovr(base,'ftype',ftypes{5},'F0',0,'A',5,'f',1,'b',3,'T',8);
P{7} = ovr(base,'ftype',ftypes{4},'F0',4,'A',8,'f',1.5,'tau',2,'T',10);

% ------------------------------------------------------------------ layout
fig = uifigure('Name','Spring-Damper Energy Lab','Position',[40 40 1420 840], ...
               'Color',[0.97 0.97 0.98]);
fig.CloseRequestFcn = @(~,~) onClose();

root = uigridlayout(fig,[1 2]);
root.ColumnWidth = {360,'1x'};
root.Padding = [8 8 8 8];

lp = uipanel(root,'Title','Control Deck','FontWeight','bold');
gl = uigridlayout(lp,[22 2]);
gl.RowHeight = [repmat({26},1,21),{250}];
gl.ColumnWidth = {'1x',140};
gl.RowSpacing = 4;
gl.Scrollable = 'on';

r = 1;
ddField(r,'preset','Scenario',presetNames,presetNames{1}, ...
        'Jump-start with an interesting setup, then tweak anything.', @(~,~) applyPreset()); r=r+1;
header(r,'1) Applied force F(t)  (always bounded)'); r=r+1;
ddField(r,'ftype','Shape',ftypes,base.ftype,'All shapes settle to, or oscillate around, a constant.', @(~,~) onForceType()); r=r+1;
numField(r,'F0','Mean / final value F0 [N]',base.F0,[-1e4 1e4],'Constant level the force settles to or oscillates around.'); r=r+1;
numField(r,'A','Amplitude A [N]',base.A,[0 1e4],'Size of the oscillation (sine, damped sine, square).'); r=r+1;
numField(r,'f','Frequency f [Hz]',base.f,[0 100],'Oscillation frequency.'); r=r+1;
numField(r,'tau','Time const / width tau [s]',base.tau,[1e-3 1e4],'Settling time (exponential, damped sine) or pulse width.'); r=r+1;
header(r,'2) Spring'); r=r+1;
ddField(r,'stype','Law',stypes,base.stype,'Linear, stiffening, or softening/saturating spring.', @(~,~) onLawChange()); r=r+1;
numField(r,'k','Stiffness k [N/m]',base.k,[1e-3 1e5],'Linear stiffness.'); r=r+1;
numField(r,'kshape','Shape: k3 or L',base.kshape,[1e-3 1e5],'Hardening: k3 [N/m^3].  Softening: saturation length L [m].'); r=r+1;
header(r,'3) Damper'); r=r+1;
ddField(r,'dtype','Law',dtypes,base.dtype,'Linear or power-law (n=2 is a quadratic / "fluid drag" damper).', @(~,~) onLawChange()); r=r+1;
numField(r,'b','Damping b',base.b,[1e-3 1e5],'Damping coefficient (N s/m for linear).'); r=r+1;
numField(r,'n','Exponent n',base.n,[0.2 5],'Power-law exponent: F = b|v|^n sign(v).'); r=r+1;
header(r,'4) Start-up & run'); r=r+1;
numField(r,'x0','Initial extension x0 [m]',base.x0,[-100 100],'Spring extension at t = 0 (0 = natural length).'); r=r+1;
numField(r,'T','Simulation time T [s]',base.T,[0.1 1e4],'How long to simulate.'); r=r+1;

btnPin = uibutton(gl,'Text','Pin run as ghost','ButtonPushedFcn',@(~,~) pinGhost());
btnPin.Layout.Row = r; btnPin.Layout.Column = 1;
btnClr = uibutton(gl,'Text','Clear ghost','ButtonPushedFcn',@(~,~) clearGhost());
btnClr.Layout.Row = r; btnClr.Layout.Column = 2; r=r+1; %#ok<NASGU>

H.insights = uitextarea(gl,'Editable','off','FontName','Consolas','FontSize',11, ...
                        'Value',{'...'});
H.insights.Layout.Row = 22; H.insights.Layout.Column = [1 2];

% right side
rp = uigridlayout(root,[4 2]);
rp.RowHeight = {200,'1x','1x',44};
rp.ColumnWidth = {'1x','1x'};
rp.Padding = [4 4 4 4];

axA = uiaxes(rp); axA.Layout.Row = 1; axA.Layout.Column = [1 2];
axX = uiaxes(rp); axX.Layout.Row = 2; axX.Layout.Column = 1;
axF = uiaxes(rp); axF.Layout.Row = 2; axF.Layout.Column = 2;
axE = uiaxes(rp); axE.Layout.Row = 3; axE.Layout.Column = 1;
axB = uiaxes(rp); axB.Layout.Row = 3; axB.Layout.Column = 2;

pb = uigridlayout(rp,[1 4]);
pb.Layout.Row = 4; pb.Layout.Column = [1 2];
pb.ColumnWidth = {110,'1x',50,100};
pb.Padding = [0 0 0 0];
btnPlay = uibutton(pb,'Text','Play','FontWeight','bold','ButtonPushedFcn',@(~,~) onPlay());
sld = uislider(pb,'Limits',[0 10],'Value',0,'MajorTicks',[],'MinorTicks',[], ...
               'ValueChangingFcn',@(~,e) setCursor(e.Value), ...
               'ValueChangedFcn',@(s,~) setCursor(s.Value));
lblSpd = uilabel(pb,'Text','Speed','HorizontalAlignment','right'); %#ok<NASGU>
spd = uidropdown(pb,'Items',{'0.25x','0.5x','1x','2x','4x'}, ...
                 'ItemsData',[0.25 0.5 1 2 4],'Value',1);

% ---- animation scene
axA.XLim = [-0.2 2.9]; axA.YLim = [-0.5 0.5];
axA.XTick = []; axA.YTick = []; axA.XColor = 'none'; axA.YColor = 'none';
axA.Box = 'off'; hold(axA,'on');
plot(axA,[0 0],[-0.4 0.4],'k','LineWidth',4);
for yy = -0.4:0.1:0.3
    plot(axA,[0 -0.08],[yy+0.1 yy],'k','LineWidth',1);
end
hCyl  = patch(axA,[0 1.2 1.2 0],[-0.27 -0.27 -0.13 -0.13],[0.9 0.9 0.9], ...
              'EdgeColor','k','LineWidth',1.5);
hRod  = plot(axA,[1 1],[-0.2 -0.2],'k','LineWidth',3);
hHead = plot(axA,[0.5 0.5],[-0.26 -0.14],'k','LineWidth',5);
hSpr  = plot(axA,NaN,NaN,'LineWidth',3,'Color',[0.35 0.35 0.35]);
hCon  = plot(axA,[1 1],[-0.3 0.3],'k','LineWidth',6);
hLeash = plot(axA,NaN,NaN,'Color',[0.6 0.1 0.1],'LineWidth',2.5);   % the leash
catParts = makeCat(axA);                                            % tabby cat (the applied force!)
hMeow = text(axA,1.5,0.3,'','HorizontalAlignment','center','FontSize',12, ...
             'FontWeight','bold','Color',[0.6 0.25 0.05]);
text(axA,0.05,0.36,'spring (turns green as it stores energy)','FontSize',10,'Color',[0.3 0.3 0.3]);
text(axA,0.05,-0.38,'damper (glows red as it dissipates energy)','FontSize',10,'Color',[0.3 0.3 0.3]);
hTxt  = text(axA,2.88,0.45,'','HorizontalAlignment','right','FontName','Consolas', ...
             'FontSize',12,'FontWeight','bold');

% ---- plots
cW = [0.1 0.3 0.8]; cU = [0.1 0.65 0.25]; cD = [0.85 0.2 0.1]; cK = [0.2 0.2 0.2];
gray = @(c) 0.5 + 0.5*c;

hold(axX,'on');
hgX = plot(axX,NaN,NaN,'--','Color',[0.6 0.6 0.6],'LineWidth',1.5);
hX  = plot(axX,NaN,NaN,'Color',cW,'LineWidth',2);
cX  = xline(axX,0,':k');
title(axX,'Spring extension x(t)'); xlabel(axX,'time [s]'); ylabel(axX,'x [m]'); grid(axX,'on');
legend(axX,[hX hgX],{'x(t)','pinned run'},'Location','best');

hold(axF,'on');
hFa = plot(axF,NaN,NaN,'Color',cK,'LineWidth',2.2);
hFs = plot(axF,NaN,NaN,'Color',cU,'LineWidth',1.6);
hFd = plot(axF,NaN,NaN,'Color',cD,'LineWidth',1.6);
cF  = xline(axF,0,':k');
title(axF,'Who carries the load?  F = F_{spring} + F_{damper}');
xlabel(axF,'time [s]'); ylabel(axF,'force [N]'); grid(axF,'on');
legend(axF,[hFa hFs hFd],{'applied F','spring','damper'},'Location','best');

hold(axE,'on');
hgW = plot(axE,NaN,NaN,':','Color',gray(cW),'LineWidth',1.5);
hgU = plot(axE,NaN,NaN,':','Color',gray(cU),'LineWidth',1.5);
hgD = plot(axE,NaN,NaN,':','Color',gray(cD),'LineWidth',1.5);
hSum = plot(axE,NaN,NaN,'--','Color',[0.55 0.55 0.55],'LineWidth',4);
hW  = plot(axE,NaN,NaN,'Color',cW,'LineWidth',2);
hU  = plot(axE,NaN,NaN,'Color',cU,'LineWidth',2);
hD  = plot(axE,NaN,NaN,'Color',cD,'LineWidth',2);
cE  = xline(axE,0,':k');
title(axE,'Energy bookkeeping'); xlabel(axE,'time [s]'); ylabel(axE,'energy [J]'); grid(axE,'on');
legend(axE,[hW hU hD hSum],{'work by F (W)','spring stored (U)','damper dissipated (D)','U + D'}, ...
       'Location','best');

hBar = bar(axB,1:3,[0 0 0],'FaceColor','flat');
hBar.CData = [cW; cU; cD];
axB.XTick = 1:3; axB.XTickLabel = {'Work in (W)','Stored (U)','Dissipated (D)'};
title(axB,'Energy at the cursor time'); ylabel(axB,'energy [J]'); grid(axB,'on');

% ---------------------------------------------------------------- go
setEnables();
simulate();

% =================================================================
%                        nested helper functions
% =================================================================
    function header(row,txt)
        l = uilabel(gl,'Text',txt,'FontWeight','bold','FontColor',[0.1 0.25 0.55]);
        l.Layout.Row = row; l.Layout.Column = [1 2];
    end

    function numField(row,key,labelText,val,lims,tip)
        l = uilabel(gl,'Text',labelText,'Tooltip',tip);
        l.Layout.Row = row; l.Layout.Column = 1;
        H.(key) = uieditfield(gl,'numeric','Value',val,'Limits',lims, ...
                              'Tooltip',tip,'ValueChangedFcn',@(~,~) simulate());
        H.(key).Layout.Row = row; H.(key).Layout.Column = 2;
    end

    function ddField(row,key,labelText,items,val,tip,cb)
        l = uilabel(gl,'Text',labelText,'Tooltip',tip);
        l.Layout.Row = row; l.Layout.Column = 1;
        H.(key) = uidropdown(gl,'Items',items,'Value',val,'Tooltip',tip,'ValueChangedFcn',cb);
        H.(key).Layout.Row = row; H.(key).Layout.Column = 2;
    end

    function setEnables()
        ft = H.ftype.Value;
        H.A.Enable   = onoff(any(strcmp(ft,{ftypes{3},ftypes{4},ftypes{5}})));
        H.f.Enable   = onoff(any(strcmp(ft,{ftypes{3},ftypes{4},ftypes{5}})));
        H.tau.Enable = onoff(any(strcmp(ft,{ftypes{2},ftypes{4},ftypes{6}})));
        H.kshape.Enable = onoff(~startsWith(H.stype.Value,'Linear'));
        H.n.Enable      = onoff(~startsWith(H.dtype.Value,'Linear'));
    end

    function onForceType(),  setEnables(); simulate(); end
    function onLawChange(),  setEnables(); simulate(); end

    function applyPreset()
        idx = find(strcmp(presetNames,H.preset.Value),1);
        s = P{idx};
        fn = fieldnames(s);
        for i = 1:numel(fn)
            H.(fn{i}).Value = s.(fn{i});
        end
        setEnables();
        simulate();
    end

    function p = getParams()
        p.ftype = H.ftype.Value; p.F0 = H.F0.Value; p.A = H.A.Value;
        p.f = H.f.Value; p.tau = H.tau.Value;
        p.stype = H.stype.Value; p.k = H.k.Value; p.kshape = H.kshape.Value;
        p.dtype = H.dtype.Value; p.b = H.b.Value; p.n = H.n.Value;
        if startsWith(p.dtype,'Linear'), p.n = 1; end
        p.x0 = H.x0.Value; p.T = H.T.Value;
    end

    function simulate()
        try
            p = getParams();
            tspan = linspace(0,p.T,1201);
            opts = odeset('RelTol',1e-7,'AbsTol',1e-9);
            y0 = [p.x0; 0; 0];
            rhs = @(tt,y) odeRhs(p,tt,y);
            if p.n == 1
                [t,Y] = ode15s(rhs,tspan,y0,opts);
            else
                [t,Y] = ode45(rhs,tspan,y0,opts);
            end
            x  = Y(:,1);
            F  = forceFun(p,t);
            Fs = springForce(p,x);
            Fd = F - Fs;
            v  = damperVel(p,Fd);
            S.p = p; S.t = t; S.x = x; S.W = Y(:,2); S.D = Y(:,3);
            S.U = springEnergy(p,x);
            S.F = F; S.Fs = Fs; S.Fd = Fd; S.Pd = Fd.*v;
            S.T = p.T;
            xm = max(abs(x)); if xm < 1e-12, xm = 1; end
            S.scale = 0.6/xm;
            S.Fmax = max(abs(F)); if S.Fmax < 1e-12, S.Fmax = 1; end
            S.tc = min(S.tc,S.T);
            refreshPlots();
            writeInsights();
            sld.Limits = [0 S.T];
            sld.Value = S.tc;
            setCursor(S.tc);
        catch err
            uialert(fig,err.message,'Simulation problem');
        end
    end

    function refreshPlots()
        set(hX,'XData',S.t,'YData',S.x);
        set(hFa,'XData',S.t,'YData',S.F);
        set(hFs,'XData',S.t,'YData',S.Fs);
        set(hFd,'XData',S.t,'YData',S.Fd);
        set(hW,'XData',S.t,'YData',S.W);
        set(hU,'XData',S.t,'YData',S.U);
        set(hD,'XData',S.t,'YData',S.D);
        set(hSum,'XData',S.t,'YData',S.U + S.D);
        g = S.ghost;
        if isempty(g)
            set([hgX hgW hgU hgD],{'XData'},{NaN;NaN;NaN;NaN},{'YData'},{NaN;NaN;NaN;NaN});
        else
            set(hgX,'XData',g.t,'YData',g.x);
            set(hgW,'XData',g.t,'YData',g.W);
            set(hgU,'XData',g.t,'YData',g.U);
            set(hgD,'XData',g.t,'YData',g.D);
        end
        axX.XLim = [0 S.T]; axF.XLim = [0 S.T]; axE.XLim = [0 S.T];
    end

    function setCursor(tcNew)
        S.tc = max(0,min(S.T,tcNew));
        N = numel(S.t);
        idx = max(1,min(N,round(S.tc/S.T*(N-1))+1));
        drawFrame(idx);
        if ~S.playing, return; end
        sld.Value = S.tc;
    end

    function drawFrame(idx)
        pp = 1 + S.x(idx)*S.scale;
        % spring
        [zx,zy] = zigzagPts(0,pp,0.2,8,0.08);
        Umax = max(S.U); if Umax < 1e-12, Umax = 1; end
        gU = min(1,max(0,S.U(idx)/Umax));
        set(hSpr,'XData',zx,'YData',zy,'Color',(1-gU)*[0.35 0.35 0.35] + gU*[0.1 0.75 0.2]);
        % damper
        hx = max(0.05,pp-0.55);
        set(hRod,'XData',[pp hx],'YData',[-0.2 -0.2]);
        set(hHead,'XData',[hx hx]);
        Pmax = max(S.Pd); if Pmax < 1e-12, Pmax = 1; end
        gD = min(1,max(0,S.Pd(idx)/Pmax));
        set(hCyl,'FaceColor',(1-gD)*[0.92 0.92 0.92] + gD*[1 0.3 0.1]);
        % connector + force arrow
        set(hCon,'XData',[pp pp]);
        % tabby cat on a leash: the harder the force, the harder it pulls
        tens = max(0,S.F(idx)/S.Fmax);
        dir = 1;
        if S.F(idx) < -0.05*S.Fmax, dir = -1; end     % negative force: cat turns around
        sc = 1.1; ky = 1.8;                           % ky stretches the cat to look right on screen
        if dir == 1
            leashLen = 0.12 + 0.45*tens;
            cx = pp + leashLen - 0.095*sc;
        else
            cx = pp + 0.15 + 0.095*sc;
        end
        placeCat(catParts,cx,0,dir,sc,ky);
        ex = cx + dir*sc*0.095;  ey = ky*sc*0.03;     % collar position
        u = linspace(0,1,14);
        sag = 0.1*(1 - tens);                         % slack leash droops, taut leash is straight
        set(hLeash,'XData',pp + (ex-pp)*u,'YData',ey*u - sag*4*u.*(1-u));
        if tens > 0.85
            msg = 'MRROW!';
        elseif dir == -1
            msg = 'wait up...';
        else
            msg = '';
        end
        set(hMeow,'String',msg,'Position',[cx 0.3 0]);
        set(hTxt,'String',sprintf('t = %5.2f s   x = %6.3f m   F = %6.2f N',S.t(idx),S.x(idx),S.F(idx)));
        % cursors + bars
        cX.Value = S.t(idx); cF.Value = S.t(idx); cE.Value = S.t(idx);
        vals = [S.W(idx) S.U(idx) S.D(idx)];
        hBar.YData = vals;
        top = max([abs(S.W); S.U; S.D; 1e-9]);
        axB.YLim = [min(0,min(S.W))*1.1 - 1e-9, top*1.15];
    end

    function writeInsights()
        p = S.p;
        Wf = S.W(end); Uf = S.U(end); Df = S.D(end);
        U0 = springEnergy(p,p.x0);
        L = {};
        if startsWith(p.stype,'Linear') && startsWith(p.dtype,'Linear')
            L{end+1} = sprintf('Time constant  tau = b/k = %.3g s',p.b/p.k);
            L{end+1} = sprintf('Corner freq    fc = k/(2*pi*b) = %.3g Hz',p.k/(2*pi*p.b));
            L{end+1} = '(drive well below fc: spring wins;';
            L{end+1} = ' well above fc: damper wins)';
        else
            L{end+1} = 'Nonlinear: no single tau - the system';
            L{end+1} = 'reacts faster/slower depending on stretch.';
        end
        L{end+1} = '';
        L{end+1} = sprintf('Initial stored energy U0 = %.3g J',U0);
        L{end+1} = sprintf('Work by F (final)    W  = %.3g J',Wf);
        L{end+1} = sprintf('Spring stored (final) U = %.3g J',Uf);
        L{end+1} = sprintf('Dissipated (final)    D = %.3g J',Df);
        tot = Uf + Df;
        if tot > 1e-9
            fd = 100*Df/tot;
            L{end+1} = sprintf('Of the energy supplied: %.0f%% heat, %.0f%% stored',fd,100-fd);
            if fd > 70,     L{end+1} = '=> mostly a HEATER (damper-dominated)';
            elseif fd < 30, L{end+1} = '=> mostly a BATTERY (spring-dominated)';
            else,           L{end+1} = '=> a balanced energy split';
            end
        end
        err = max(abs(S.W + U0 - S.U - S.D));
        L{end+1} = sprintf('Energy balance error: %.1e J',err);
        L{end+1} = '';
        L{end+1} = 'Tip: Pin this run, change b or k,';
        L{end+1} = 'and watch the dotted ghost curves.';
        H.insights.Value = L;
    end

    function pinGhost()
        S.ghost = struct('t',S.t,'x',S.x,'W',S.W,'U',S.U,'D',S.D);
        refreshPlots();
    end

    function clearGhost()
        S.ghost = [];
        refreshPlots();
    end

    function onPlay()
        if S.playing
            S.playing = false;
            return;
        end
        S.playing = true;
        btnPlay.Text = 'Pause';
        if S.tc >= S.T - 1e-9, S.tc = 0; end
        t0 = S.tc;
        clk = tic;
        while S.playing && isvalid(fig)
            tcNew = t0 + toc(clk)*(S.T/10)*spd.Value;
            if tcNew >= S.T
                tcNew = S.T;
                S.playing = false;
            end
            setCursorPlaying(tcNew);
            drawnow limitrate;
        end
        if isvalid(fig)
            S.playing = false;
            btnPlay.Text = 'Play';
        end
    end

    function setCursorPlaying(tcNew)
        S.tc = max(0,min(S.T,tcNew));
        N = numel(S.t);
        idx = max(1,min(N,round(S.tc/S.T*(N-1))+1));
        drawFrame(idx);
        sld.Value = S.tc;
    end

    function onClose()
        S.playing = false;
        delete(fig);
    end
end

% =================================================================
%                          local physics functions
% =================================================================
function s = ovr(s,varargin)
for i = 1:2:numel(varargin)
    s.(varargin{i}) = varargin{i+1};
end
end

function str = onoff(tf)
if tf, str = 'on'; else, str = 'off'; end
end

function F = forceFun(p,t)
switch p.ftype
    case 'Step (constant)'
        F = p.F0*ones(size(t));
    case 'Exponential settle'
        F = p.F0*(1 - exp(-t/p.tau));
    case 'Sine around offset'
        F = p.F0 + p.A*sin(2*pi*p.f*t);
    case 'Damped sine'
        F = p.F0 + p.A*exp(-t/p.tau).*sin(2*pi*p.f*t);
    case 'Square wave'
        F = p.F0 + p.A*tanh(sin(2*pi*p.f*t)/0.05);   % smoothed square wave
    case 'Pulse then release'
        w = 0.005*p.T + 1e-6;
        F = p.F0*0.5*(1 - tanh((t - p.tau)/w));
    otherwise
        F = zeros(size(t));
end
end

function Fs = springForce(p,x)
if startsWith(p.stype,'Linear')
    Fs = p.k*x;
elseif startsWith(p.stype,'Hardening')
    Fs = p.k*x + p.kshape*x.^3;
else
    L = p.kshape;
    Fs = p.k*L*tanh(x/L);
end
end

function U = springEnergy(p,x)
if startsWith(p.stype,'Linear')
    U = 0.5*p.k*x.^2;
elseif startsWith(p.stype,'Hardening')
    U = 0.5*p.k*x.^2 + 0.25*p.kshape*x.^4;
else
    L = p.kshape;
    z = abs(x)/L;
    U = p.k*L^2*(z + log1p(exp(-2*z)) - log(2));   % = k L^2 ln(cosh(x/L)), overflow-safe
end
end

function v = damperVel(p,R)
% Invert damper law  R = b |v|^n sign(v)  ->  v
v = sign(R).*(abs(R)/p.b).^(1/p.n);
end

function dy = odeRhs(p,tt,y)
Ft = forceFun(p,tt);
Fs = springForce(p,y(1));
R  = Ft - Fs;            % force the damper must carry
v  = damperVel(p,R);
dy = [v; Ft*v; R*v];     % [dx/dt; dW/dt = F v; dD/dt = Fd v]
end

function [zx,zy] = zigzagPts(x0,x1,y,n,amp)
d  = x1 - x0;
xi = linspace(x0+0.1*d,x1-0.1*d,2*n+1);
yi = y + amp*[0,(-1).^(1:2*n-1),0];
zx = [x0 xi x1];
zy = [y yi y];
end

function parts = makeCat(ax)
% Builds a little tabby cat out of patches and lines (facing right, local coords).
orange = [0.88 0.58 0.25];  dark = [0.4 0.2 0.05];
th = linspace(0,2*pi,30);
items = {
 'line', [-0.08 -0.11], [-0.05 -0.12], orange, 5      % back legs
 'line', [-0.05 -0.04], [-0.05 -0.12], orange, 5
 'line', [0.07 0.10],   [-0.05 -0.12], orange, 5      % front legs
 'line', [0.04 0.04],   [-0.05 -0.12], orange, 5
 'line', [-0.12 -0.17 -0.20 -0.20], [0.02 0.05 0.10 0.16], orange, 6   % tail
 'patch', 0.12*cos(th), 0.07*sin(th), orange, 1       % body
 'patch', [0.095 0.125 0.10], [0.09 0.105 0.16], orange, 1   % ears
 'patch', [0.155 0.185 0.18], [0.108 0.09 0.16], orange, 1
 'patch', 0.14+0.06*cos(th), 0.05+0.06*sin(th), orange, 1    % head
 'line', [0.12 0.12], [0.11 0.088], dark, 2           % forehead stripes
 'line', [0.14 0.14], [0.11 0.085], dark, 2
 'line', [0.16 0.16], [0.11 0.088], dark, 2
 'line', [0.09 0.10], [-0.01 0.08], [0.8 0.1 0.1], 4  % collar
 'dot',  0.162, 0.065, [0 0 0], 12                    % eye
 'dot',  0.198, 0.045, [1 0.55 0.65], 9               % nose
};
for xs = [-0.08 -0.04 0 0.04]                          % body stripes
    yt = 0.07*sqrt(1 - (xs/0.12)^2);
    items(end+1,:) = {'line', [xs xs], [yt yt-0.04], dark, 2}; %#ok<AGROW>
end
n = size(items,1);
parts = struct('h',cell(1,n),'x',[],'y',[]);
for i = 1:n
    kind = items{i,1}; px = items{i,2}; py = items{i,3}; c = items{i,4}; w = items{i,5};
    switch kind
        case 'patch'
            h = patch(ax,px,py,c,'EdgeColor',dark,'LineWidth',1);
        case 'line'
            h = plot(ax,px,py,'Color',c,'LineWidth',w);
        otherwise
            h = plot(ax,px,py,'.','Color',c,'MarkerSize',w);
    end
    parts(i).h = h; parts(i).x = px; parts(i).y = py;
end
end

function placeCat(parts,cx,cy,dir,s,ky)
% Move/flip the cat. dir = +1 faces right, -1 faces left.
for i = 1:numel(parts)
    set(parts(i).h,'XData',cx + dir*s*parts(i).x,'YData',cy + ky*s*parts(i).y);
end
end
