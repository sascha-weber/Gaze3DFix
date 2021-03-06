library Gaze3D;

{

  Gaze 3D Library Unit
  ====================
    Sascha Weber 12.05.2016
    Calculates the 3D gaze point.

  Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  SysUtils,
  Classes,
  u3DAlgorithm in 'units\u3DAlgorithm.pas',
  u3DVector in 'units\u3DVector.pas';



{$R *.res}

function CalculateGaze3DFromEyePos(x_EyePos_Left,
                                   y_EyePos_Left,
                                   z_EyePos_Left,

                                   x_GazePos_Left,
                                   y_GazePos_Left,
                                   z_GazePos_Left,

                                   x_EyePos_Right,
                                   y_EyePos_Right,
                                   z_EyePos_Right,

                                   x_GazePos_Right,
                                   y_GazePos_Right,
                                   z_GazePos_Right: Int32;

                               out x_Gaze3D,
                                   y_Gaze3D,
                                   z_Gaze3D: Int32): Int32; stdcall;

var
  vEL,vER :TVector;           // vectors left and right eye
  vGL,vGR :TVector;           // vectors left and right gaze

  v3DGazePosition: TVector;   // Result

begin
  try

    vEL.x1:=x_EyePos_Left;
    vEL.x2:=y_EyePos_Left;
    vEL.x3:=z_EyePos_Left;

    vGL.x1:=x_GazePos_Left;
    vGL.x2:=y_GazePos_Left;
    vGL.x3:=z_GazePos_Left;

    vER.x1:=x_EyePos_Right;
    vER.x2:=y_EyePos_Right;
    vER.x3:=z_EyePos_Right;

    vGR.x1:=x_GazePos_Right;
    vGR.x2:=y_GazePos_Right;
    vGR.x3:=z_GazePos_Right;

    v3DGazePosition:=Calculate3dSVAlgorithm_SkewLines(vEL,vMakeDirVector(vEL,vGL),vER,vMakeDirVector(vER,vGR));


    x_Gaze3D:=round(v3DGazePosition.x1);
    y_Gaze3D:=round(v3DGazePosition.x2);
    z_Gaze3D:=round(v3DGazePosition.x3);

    Result:=0;

  except
    on e:Exception do
    raise Exception.CreateFmt('CalclateGaze3DFromEyePos: [%s]',[e.message]);
  end;

end;

function CalculateGaze3DFromGazeVec (x_EyePos_Left,
                                     y_EyePos_Left,
                                     z_EyePos_Left,

                                     x_GazeVec_Left,
                                     y_GazeVec_Left,
                                     z_GazeVec_Left,

                                     x_EyePos_Right,
                                     y_EyePos_Right,
                                     z_EyePos_Right,

                                     x_GazeVec_Right,
                                     y_GazeVec_Right,
                                     z_GazeVec_Right: Int32;

                                 out x_Gaze3D,
                                     y_Gaze3D,
                                     z_Gaze3D: Int32): Int32; stdcall;

var
  vEL,vER :TVector;           // vectors left and right eye
  vGL,vGR :TVector;           // vectors left and right gaze

  v3DGazePos: TVector;        // Result

begin
  try

    vEL.x1:=x_EyePos_Left;
    vEL.x2:=y_EyePos_Left;
    vEL.x3:=z_EyePos_Left;

    vGL.x1:=x_GazeVec_Left;
    vGL.x2:=y_GazeVec_Left;
    vGL.x3:=z_GazeVec_Left;

    vER.x1:=x_EyePos_Right;
    vER.x2:=y_EyePos_Right;
    vER.x3:=z_EyePos_Right;

    vGR.x1:=x_GazeVec_Right;
    vGR.x2:=y_GazeVec_Right;
    vGR.x3:=z_GazeVec_Right;


    v3DGazePos:=Calculate3dSVAlgorithm_SkewLines(vEL,vGL,vER,vGR);

    x_Gaze3D:=round(v3DGazePos.x1);
    y_Gaze3D:=round(v3DGazePos.x2);
    z_Gaze3D:=round(v3DGazePos.x3);

    Result:=0;

  except
    on e:Exception do
    raise Exception.CreateFmt('CalculateGaze3DFromGazeVectors: [%s]',[e.message]);
  end;

end;

function CalculateVergenceAngle     (x_GazeVec_Left,
                                     y_GazeVec_Left,
                                     z_GazeVec_Left,

                                     x_GazeVec_Right,
                                     y_GazeVec_Right,
                                     z_GazeVec_Right: Int32;

                                 out VergenceAngle: Double): Int32; stdcall;

var
  vGL,vGR :TVector;           // vectors left and right gaze
begin
  try

    vGL.x1:=x_GazeVec_Left;
    vGL.x2:=y_GazeVec_Left;
    vGL.x3:=z_GazeVec_Left;

    vGR.x1:=x_GazeVec_Right;
    vGR.x2:=y_GazeVec_Right;
    vGR.x3:=z_GazeVec_Right;

    VergenceAngle:=CalculateGazeVectorAngle(vGL,vGR);

    Result:=0;

  except
    on e:Exception do
    raise Exception.CreateFmt('CalculateGaze3DFromGazeVectors: [%s]',[e.message]);
  end;

end;

exports
  CalculateGaze3DFromEyePos,
  CalculateGaze3DFromGazeVec,
  CalculateVergenceAngle;

begin
end.
