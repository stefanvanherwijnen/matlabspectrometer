function varargout = spectrometer(varargin)
% SPECTROMETER MATLAB code for spectrometer.fig
% spectrometer.m launches a GUI for Ocean Optics spectrometers which
% displays a realtime plot of the data and the option to save a spectrum

% Begin initialization code - DO NOT EDIT
clc;

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @spectrometer_OpeningFcn, ...
                   'gui_OutputFcn',  @spectrometer_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before spectrometer is made visible.
function spectrometer_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to spectrometer (see VARARGIN)

% Choose default command line output for spectrometer
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% This sets up the initial spectrumPlot - only do when we are invisible
% so window can get raised using spectrometer.
global plotData
if strcmp(get(hObject,'Visible'),'off')
   plotData = plot(rand(5));
end

ylim(handles.spectrumPlot,[0 60000]);
xlim(handles.spectrumPlot,[200 900]);
grid;
xlabel(handles.spectrumPlot, 'Wavelength [nm]')
ylabel(handles.spectrumPlot, 'Counts')


integrationTime = str2double(get(handles.integrationTime, 'String'));
scansToAverage = str2double(get(handles.scansToAverage, 'String'));
period = integrationTime/1e6 * scansToAverage;

global spectrometerObj
try
    spectrometerObj = initializeSpectrometer(handles);
    global t;
    t = timer('TimerFcn',  @plotRealtimeSpectrum, 'Period', period, 'ExecutionMode', 'fixedRate', 'BusyMode', 'queue');
    start(t);
    set(handles.sampleTime,'String', period);
catch Exception
    msgbox(Exception.message)
end
% UIWAIT makes spectrometer wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = spectrometer_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in saveSpectrum.
function saveSpectrum_Callback(hObject, eventdata, handles)
% hObject    handle to saveSpectrum (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global t spectrometerObj
integrationTime = str2double(get(handles.integrationTime, 'String'));
scansToAverage = str2double(get(handles.scansToAverage, 'String'));

stop(t);

% Delay in order to 'flush' the buffer of the spectrometer
% The measurement starts after the button is pressed, instead of using
% earlier obtained scans which are still left in the buffer.
java.lang.Thread.sleep(integrationTime/1e3 * scansToAverage);

numberOfScans = str2num(get(handles.numberOfScans, 'String'));
data = [];

for i = 1:numberOfScans
    [wavelengths spectralData] = acquireSpectrum(spectrometerObj, 0, 0);
    data(:,:,i) = [wavelengths spectralData];
end

figure;
title(datestr(datetime));
hold all
for i = 1:numberOfScans
    plot(data(:,1,i), data(:,2,i));
end

try
    [filename directory] = uiputfile({'*.txt','Text file';'*.*','All Files' },'Select output file')
    [filepath,name,ext] = fileparts(filename)

    for fileNr = 1:numberOfScans
        filePath = strcat(directory, name, num2str(fileNr), ext);
        fid = fopen(filePath, 'w');
        fprintf(fid, 'Integration Time (usec): %d\n', integrationTime);
        fclose(fid);
        dlmwrite(filePath, data(:,:,fileNr), 'delimiter', '\t', 'newline', 'pc', 'precision', 3, '-append');
    end
catch Exception
    msgbox(Exception.message);
end
start(t);



% --------------------------------------------------------------------
function FileMenu_Callback(hObject, eventdata, handles)
% hObject    handle to FileMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OpenMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to OpenMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
file = uigetfile('*.fig');
if ~isequal(file, 0)
    open(file);
end

% --------------------------------------------------------------------
function PrintMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to PrintMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
printdlg(handles.figure1)

% --------------------------------------------------------------------
function CloseMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to CloseMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
selection = questdlg(['Close ' get(handles.figure1,'Name') '?'],...
                     ['Close ' get(handles.figure1,'Name') '...'],...
                     'Yes','No','Yes');
if strcmp(selection,'No')
    return;
end

delete(handles.figure1)


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1


% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
     set(hObject,'BackgroundColor','white');
end

set(hObject, 'String', {'plot(rand(5))', 'plot(sin(1:0.01:25))', 'bar(1:.5:10)', 'plot(membrane)', 'surf(peaks)'});



function integrationTime_Callback(hObject, eventdata, handles)
% hObject    handle to integrationTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of integrationTime as text
%        str2double(get(hObject,'String')) returns contents of integrationTime as a double
global t spectrometerObj
integrationTime = str2double(get(hObject, 'String'));

if (3.8e3 <= integrationTime && integrationTime <= 10e6)
    scansToAverage = str2double(get(handles.scansToAverage, 'String'));
    period = integrationTime/1e6 * scansToAverage;

    stop(t);
    try
        setSpectrometerProperty(spectrometerObj, 'setIntegrationTime', integrationTime);
        set(t, 'Period', period);
        set(hObject,'UserData',integrationTime);
        set(handles.sampleTime,'String', period);
        start(t);
    catch Exception
        msgbox(Exception.message);
    end
else
    msgbox('Integration time not supported');
    integrationTimePrev=get(hObject,'UserData');
    set(hObject,'String',integrationTimePrev);
end

% --- Executes during object creation, after setting all properties.
function integrationTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to integrationTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'UserData',str2double(get(hObject, 'String')));


function scansToAverage_Callback(hObject, eventdata, handles)
% hObject    handle to scansToAverage (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of scansToAverage as text
%        str2double(get(hObject,'String')) returns contents of scansToAverage as a double
global spectrometerObj
global t
scansToAverage = str2double(get(hObject, 'String'));

%invoke(spectrometerObj, 'setScansToAverage', spectrometerIndex, channelIndex, scansToAverage);

integrationTime = str2double(get(handles.integrationTime, 'String'));
period = integrationTime/1e6 * scansToAverage;

stop(t);

try
    set(handles.sampleTime,'String', period);
    set(t, 'Period', period);
    setSpectrometerProperty(spectrometerObj, 'setScansToAverage', scansToAverage);
    start(t);
catch Exception
    msgbox(Exception.message);
end

% --- Executes during object creation, after setting all properties.
function scansToAverage_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scansToAverage (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function boxcarWidth_Callback(hObject, eventdata, handles)
% hObject    handle to boxcarWidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of boxcarWidth as text
%        str2double(get(hObject,'String')) returns contents of boxcarWidth as a double
global spectrometerObj
boxcarWidth = str2double(get(hObject, 'String'));
setSpectrometerProperty(spectrometerObj, 'setBoxcarWidth', boxcarWidth);

% --- Executes during object creation, after setting all properties.
function boxcarWidth_CreateFcn(hObject, eventdata, handles)
% hObject    handle to boxcarWidth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function numberOfScans_Callback(hObject, eventdata, handles)
% hObject    handle to numberOfScans (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of numberOfScans as text
%        str2double(get(hObject,'String')) returns contents of numberOfScans as a double


% --- Executes during object creation, after setting all properties.
function numberOfScans_CreateFcn(hObject, eventdata, handles)
% hObject    handle to numberOfScans (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% Initialize the spectrometer
function spectrometerObj = initializeSpectrometer(handles)
spectrometerObj = icdevice('OceanOptics_OmniDriver.mdd');
connect(spectrometerObj);
disp(spectrometerObj);

integrationTime = str2double(get(handles.integrationTime, 'String'));
scansToAverage = str2double(get(handles.scansToAverage, 'String'));
boxcarWidth = str2double(get(handles.boxcarWidth, 'String'));

% Set integration time.
setSpectrometerProperty(spectrometerObj, 'setIntegrationTime', integrationTime);
% Enable correct for detector non-linearity.
setSpectrometerProperty(spectrometerObj, 'setCorrectForDetectorNonlinearity', 1);
% Set scans to average
setSpectrometerProperty(spectrometerObj, 'setScansToAverage', scansToAverage);
% Set boxcar width
setSpectrometerProperty(spectrometerObj, 'setBoxcarWidth', boxcarWidth);

% Wrapper to set spectrometer property
function setSpectrometerProperty(spectrometerObj, property, value)
invoke(spectrometerObj, property, 0, 0, value);
return

% Function to plot a real time spectrum in the GUI
function plotRealtimeSpectrum(~,~)
global plotData spectrometerObj;
drawnow
[x, y] = acquireSpectrum(spectrometerObj, 0, 0);
set(plotData,'XData',x,'YData',y);

% Acquire a spectrum from the spectrometer
function [wavelengths, spectralData] = acquireSpectrum(spectrometerObj, spectrometerIndex, channelIndex)
wavelengths = invoke(spectrometerObj, 'getWavelengths', spectrometerIndex, channelIndex);
spectralData = invoke(spectrometerObj, 'getSpectrum', spectrometerIndex, channelIndex);
return


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close all;
