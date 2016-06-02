//****************************************************************************************************************************************************
//****************************************************************************************************************************************************
//***
//***
//***       FixFuncClass3dCalcByEllipsoid - dispersion based detection of 3D fixations with ellipsoid accanptance space
//***       ===========================================================================================================
//***
//***       02.06.2016
//***       Sascha Weber (sascha.weber@tu-dresden.de)
//***
//***
//***       Description:      This function accpts 3D gazepoints and detects 3D fixations and saccades by a dispersion based algorithm with an
//***                         ellipsoid tolerance area. Is the minimal number of 3D gazepoints located in the aceptance space, the fixatoin
//***                         hypothesis is confirmed. With each new sample the fixation hypothesis is tested again and if it's already confirmed
//***                         the new sample will be added to the current fixation. The output parameters contains e.g. the position and duration
//***                         of the 3D fixation and the duration of the previous saccade. For the detailled specifications of the parameters and
//***                         functionality of the algorithm see the comments in the source code below.
//***
//***
//***       Implementation:   The spatial fixation detection logic with the ellipsoid tolerance area was implemented into the LC Technologies, Inc.
//***                         fixfunc.h in cooperation with Dixon Cleveland and extends the estimation of 2D fixations to the third dimension.
//***
//***                         original 2D fixation detection             File Name:       FIXFUNC.C
//***                                                                    Program Name:    Eye Fixation Analysis Functions
//***                                                                    Company:         LC Technologies, Inc.
//***                                                                                     10363 Democracy Lane
//***                                                                                     Fairfax, VA 22030
//***                                                                                     (703) 385-8800
//***                                                                    Date Created:    10/20/89
//***                                                                                     04/12/95 modified: turned into collection of functions
//***
//***
//***
//***
//***




unit FixFuncClass3dCalcByEllipsoid;
interface
uses Windows, CodeSiteLogging;

type
  TFixFuncClass3dCalcByEllipsoid = class
  const
    RING_SIZE = 121;                    // *  size of the ring buffer, length of the delay line in DetectFixation ()
                                        // *  should be greater than iMinimumFixSamples

                                        // *  the 3 types of fixations tracked by the algorithm
    NEW_FIX = 0;			                  // *  new fixation
    PRES_FIX = 1;                       // *  present fixation
    PREV_FIX = 2;                       // *  previous fixation


  //**************************************************************************************************************************************************
  //* STRUCTURES DEFINITIONS:

  Type
    _stFix = record 			              // *  FIXATION DATA
      iStartCount: Integer; 		        // *  call count to DetectFixation() when the fixation started
      iEndCount: Integer; 		          // *  call count to DetectFixation() when the fixation ended

      iNEyeFoundSamples: Integer; 	    // *  number of eye-found gazepoint samples
                                        // *    collected so far in the fixation hypothesis
                                        // *    NOTE: If iNEyeFoundSamples is 0, the
                                        // *          fixation hypothesis does not exist,
                                        // *          i.e. there is no gazepoint data to
                                        // *          support an existence hypothesis for
                                        // *          the fixation.

      fXSum: Single; 			              // *  summations for calculation of average fixation position
      fYSum: Single;
      fZSum: Single;

      fX: Single;  	  		              // *  average coordinate of the eye fixation pooint (user selected units)
      fY: Single;
      fZ: Single;

      fXEllipsoidR: Single;             // *  parameters of the ellipsoid (position and orientation) in space
      fYEllipsoidR: Single;
      fZEllipsoidR: Single;
      fEllipsoidYaw: Single;
      fEllipsoidPitch: Single;

      bFixationVerified: Integer; 	    // *  flag indicating whether the fixation hypothesis has been verified
    end;

    _stRingBuf = record 		            // *  RING BUFFER STORING PAST GAZEPOINT AND FIXATION-STATE VALUES

      iDfCallCount: Integer; 		        // *  DetectFixation call-count at the time of the sample

      bGazeFound: Integer; 		          // *  gazepoint found flag

      fXGaze: Single; 			            // *  3D gazepoint coordinate
      fYGaze: Single;
      fZGaze: Single;

      fXFix: Single; 			              // *  current 3D fixation coordinate - includes the current gazepoint
      fYFix: Single;
      fZFix: Single;

      fXEllipsoidR: Single;             // *  current 3D ellipsoid coordinate
      fYEllipsoidR: Single;
      fZEllipsoidR: Single;
                                        // *  Euler's angle rotation in casrtesian coordinates
      fEllipsoidYaw: Single;            // *  yaw angle
      fEllipsoidPitch: Single;          // *  pitch angle

      iEyeMotionState: Integer; 	      // *  state of the eye motion: 1=MOVING, 2=FIXATING, 3=FIXATION_COMPLETED

      iSacDuration: Integer; 		        // *  saccade duration
      iFixDuration: Integer; 		        // *  fixation duration
    end;

  //**************************************************************************************************************************************************
  //*  GLOBAL FIXFUNC VARIABLES:

  private
    iDfCallCount: Integer;              // *  number of times the DetectFixation() function has been called since it was
                                        // *    initialized (depending on eyetracking sample rate)

    iNOutsidePresEllipsoid: Integer;    // *  number of successive gazepoint samples outside the present fixation's
                                        // *    acceptance ellipsoid

    bGazeInPresFix: Integer;            // *  is the current 3D gaze position inside the present fixation (1=in, 0=out)
    bGazeInNewFix:  Integer;            // *  is the current 3D gaze position in the new fixation (1=in, 0=out)

    iMaxMissedSamples: Integer;         // *  maximum number of successive gazepoint samples that may go untracked before
                                        // *    a fixation is allowed to continue

    iMaxOutSamples: Integer; 		        // *  maximum number of successive gazepoint samples that may go outside the
                                        // *    fixation acceptance ellipsoid

    stFix: array [0 .. 2] of _stFix;	  // *  prior, present and new fixations
                                        // *    NEW_FIX = 0
                                        // *    PRES_FIX = 1
                                        // *    PREV_FIX = 2

    stRingBuf: array [0 .. RING_SIZE] of _stRingBuf;

    iCurrentRingIndex: Integer;	        // *  ring index of the current gaze sample
    iRingIndexDelay: Integer;		        // *  ring index of the gaze sample taken iMinimumFixSamples ago
    siPreviousFixEndCount: Integer;     // *  end of the previous fixation

  protected
    procedure DeclarePresentFixationComplete(iMinimumFixSamples: Integer);
    procedure MoveNewFixToPresFix;
    procedure StartFixationHypothesisAtGazepoint(iNewPresOrPrev: Integer; fXGaze, fYGaze, fZGaze: Single);
    procedure TestPresentFixationHypothesis(iMinimumFixSamples: Integer);
    procedure TestPresFixHypAndUpdateRingBuffer(iMinimumFixSamples: Integer);
    procedure UpdateFixationHypothesis(iNewPresOrPrev: Integer;  fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad: Single; iMinimumFixSamples: Integer);
    procedure ResetFixationHypothesis(iNewPresOrPrev: Integer);

    procedure CalcEllipsoid(fXEyeLeft, fYEyeLeft, fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight, fXEllipsoidCenter, fYEllipsoidCenter, fZEllipsoidCenter, fAccuracyAngleRad: Single; var fXEllipsoidR, fYEllipsoidR, FZEllipsoidR, fEllipsoidYaw, fEllipsoidPitch: Single);
    function  IsGazeInFix(iNewPresOrPrev: Integer; fXEyeLeft, fYEyeLeft, fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight: Single; fXGaze, fYGaze, fZGaze: Single; fAccuracyAngleRad: Single): Integer;


  public
    gb_stRingBuf: array [0 .. RING_SIZE] of _stRingBuf;
    gb_stFix: array [0 .. 2] of _stFix;


    procedure InitFixation(iMinimumFixSamplesInit, iMaxMissedSamplesInit, iMaxOutSamplesInit: Integer);

    function DetectFixation(  bValidSample: Integer;

                              fXLeftEye: Single;
                              fYLeftEye: Single;
                              fZLeftEye: Single;

                              fXRightEye: Single;
                              fYRightEye: Single;
                              fZRightEye: Single;

                        			fXGaze: Single;
      			                  fYGaze: Single;
                              fZGaze: Single;

                              fAccuracyAngleRad: Single;
                              iMinimumFixSamples: Integer;

                 out          pbValidSampleDelayed: Integer;

                 out          pfXGazeDelayed,
                              pfYGazeDelayed,
                              pfZGazeDelayed: Single;

                 out          pfXFixDelayed,
                              pfYFixDelayed,
                              pfZFixDelayed: Single;

                 out          pfXEllipsoidRDelayed,
                              pfYEllipsoidRDelayed,
                              pfZEllipsoidRDelayed: Single;

                 out          pfEllipsoidYawDelayed,
                              pfEllipsoidPitchDelayed: Single;

                 out          piSacDurationDelayed,
                              piFixDurationDelayed: Integer): Integer;
  end;
const

  MOVING = 0;
  FIXATING = 1;
  FIXATION_COMPLETED = 2;

implementation

uses
  SysUtils;

const
  FALSE = 0;
  TRUE = 1;


procedure TFixFuncClass3dCalcByEllipsoid.ResetFixationHypothesis(iNewPresOrPrev: Integer);
// * Reset the NewPresPrev-Fixation (depending on transfer parameter value)

begin
  stFix[iNewPresOrPrev].iStartCount := 0;
  stFix[iNewPresOrPrev].iEndCount := 0;
  stFix[iNewPresOrPrev].iNEyeFoundSamples := 0; // 0 = ceclare fix hypotheses does not yet exist
  stFix[iNewPresOrPrev].fXSum := 0;
  stFix[iNewPresOrPrev].fYSum := 0;
  stFix[iNewPresOrPrev].fZSum := 0;
  stFix[iNewPresOrPrev].fX := 0;
  stFix[iNewPresOrPrev].fY := 0;
  stFix[iNewPresOrPrev].fZ := 0;
  stFix[iNewPresOrPrev].fXEllipsoidR := 0;
  stFix[iNewPresOrPrev].fYEllipsoidR := 0;
  stFix[iNewPresOrPrev].fXEllipsoidR := 0;
  stFix[iNewPresOrPrev].fEllipsoidYaw := 0;
  stFix[iNewPresOrPrev].fEllipsoidPitch := 0;
  stFix[iNewPresOrPrev].bFixationVerified := FALSE;

  // *  If resetting the present fixation,
  if (iNewPresOrPrev = PRES_FIX) then
  begin
    // *  Reset the number of consecutive gazepoints that have gone outside the present fixation's acceptance ellipsoid.
    iNOutsidePresEllipsoid := 0;
  end;
end;

function TFixFuncClass3dCalcByEllipsoid.IsGazeInFix(iNewPresOrPrev: Integer; fXEyeLeft, fYEyeLeft, fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight: Single; fXGaze, fYGaze, fZGaze: Single; fAccuracyAngleRad: Single): Integer;
// * Calculate the 3D distance between gazepoint and NewPresPrev fixation

var
    XEyeLeft,YEyeLeft,ZEyeLeft: Single;             // left eye position
    XEyeRight,YEyeRight,ZEyeRight: Single;          // right eye position
    XGaze,YGaze,ZGaze: Single;                      // gaze
    XFix,YFix,ZFix: Single;                         // fixation

    Alpha:    Single;                               // angle of accuracy in radians

    Psi, Theta: Single;                             // yaw and pitch angle between cyclops eye and current fixation

    deltaX,deltaY,deltaZ: Single;                   // deviation before ellipsoid rotation
    deltaXprime,deltaYprime,deltaZprime: Single;    // deviation after ellipsoid rotation

    XEllipsoidR,YEllipsoidR,ZEllipsoidR: Single;    // ellipsoid dimensions

    InEllipsoid: Single;                            // <=1 inside  the ellipsoid
                                                    // >1 outside the ellipsoid

begin
  // left Eye
  XEyeLeft:=fXEyeLeft;
  YEyeLeft:=fYEyeLeft;
  ZEyeLeft:=fZEyeLeft;

  // right Eye
  XEyeRight:=fXEyeRight;
  YEyeRight:=fYEyeRight;
  ZEyeRight:=fZEyeRight;

  // gaze
  XGaze:=fXGaze;
  YGaze:=fYGaze;
  ZGaze:=fZGaze;

  // accuracy angle
  Alpha:=fAccuracyAngleRad;
  //Alpha:=fAccuracyAngleRad/57.3;

  // fixation
  XFix := stFix[iNewPresOrPrev].fX;
  YFix := stFix[iNewPresOrPrev].fY;
  ZFix := stFix[iNewPresOrPrev].fZ;

  // deviations before rotation
  deltaX:=XGaze-XFix;
  deltaY:=YGaze-YFix;
  deltaZ:=ZGaze-ZFix;

  CalcEllipsoid(XEyeLeft,YEyeLeft,ZEyeLeft,XEyeRight,YEyeRight,ZEyeRight,XFix,YFix,ZFix,Alpha,XEllipsoidR,YEllipsoidR,ZEllipsoidR,Psi,Theta);

  // deviations after rotation
  deltaXprime:=deltaX*cos(Psi)+deltaZ*sin(Psi);
  deltaYprime:=deltaY*cos(Theta)+deltaZ*sin(Theta);
  deltaZprime:=deltaZ*cos(Theta)*cos(Psi)-deltaX*sin(Psi)-deltaY*sin(Theta);

  // Check if gaze is in ellipsoid
  InEllipsoid:=sqr(deltaXprime/XEllipsoidR)+sqr(deltaYprime/YEllipsoidR)+sqr(deltaZprime/ZEllipsoidR);

  if InEllipsoid<=1 then
    Result:=true
  else
    Result:=false;

end;



procedure TFixFuncClass3dCalcByEllipsoid.TestPresFixHypAndUpdateRingBuffer(iMinimumFixSamples: Integer);
// *  Each time a gazepoint is added to the present fixation hypothesis, this function tests whether the fixation hypothesis can be verified,
// *  and if the fixation is real, the function updates the ring-buffer history with the appropriate values.
// *  Recall: The iEyeMoving value in the ring buffer's current index was initialized to MOVING at the beginning of the call to DetectFixation().

var
  iRingPointOffset: Integer; 			  // *  ring index offset with respect to the current ring-buffer index
  iDumRingIndex: Integer; 			    // *  dummy ring index
  iNFixSamples: Integer; 			      // *  total number of samples in the fixation to date
  iNNewSamples: Integer; 			      // *  total number of new samples to be added to the ring-buffer's fixation

begin

  // *  If the present fixation hypothesis has not previously been verified, declare a real fixation,
  if (stFix[PRES_FIX].bFixationVerified = FALSE) then
  begin

    // *  Test the hypothesis now.  If there are enough good eye samples to �
    if (stFix[PRES_FIX].iNEyeFoundSamples >= iMinimumFixSamples) then
    begin
      // *  Declare the present fixation verified.
      stFix[PRES_FIX].bFixationVerified := TRUE;

      // *  Mark the fixation within the ring buffer:
      // *    Fill in all the samples in the ring buffer from the start through the end points of the present fixation:
      // *      Compute the total number of samples in the present fixation, including the good samples, any no-track samples and any "out"
      // *      samples now decided to be included in the fixation.
      // *  Note:  +1 to include both start and end samples.

      iNFixSamples := stFix[PRES_FIX].iEndCount - stFix[PRES_FIX].iStartCount + 1;

      // *  Make sure the number of samples does not exceed the ring-buffer size.
      Assert(iNFixSamples > 0);
      Assert(iNFixSamples <= RING_SIZE);
      if (iNFixSamples > RING_SIZE) then
        iNFixSamples := RING_SIZE;

      // * Loop backwards through the ring buffer, starting with the current ring index, for the total number of fixation samples.
      for iRingPointOffset := 0 to iNFixSamples - 1 do
      begin
        // *  Compute the ring index of the earlier point.
        iDumRingIndex := iCurrentRingIndex - iRingPointOffset;
        if (iDumRingIndex < 0) then
          Inc(iDumRingIndex, RING_SIZE);
        Assert((iDumRingIndex >= 0) and (iDumRingIndex < RING_SIZE));

        // *  Declare the sample to be fixating at the currently computed fixation point.
        stRingBuf[iDumRingIndex].iEyeMotionState := FIXATING;
        stRingBuf[iDumRingIndex].fXFix := stFix[PRES_FIX].fX;
        stRingBuf[iDumRingIndex].fYFix := stFix[PRES_FIX].fY;
        stRingBuf[iDumRingIndex].fZFix := stFix[PRES_FIX].fZ;

        stRingBuf[iDumRingIndex].fXEllipsoidR := stFix[PRES_FIX].fXEllipsoidR;
        stRingBuf[iDumRingIndex].fYEllipsoidR := stFix[PRES_FIX].fYEllipsoidR;
        stRingBuf[iDumRingIndex].fZEllipsoidR := stFix[PRES_FIX].fZEllipsoidR;
        stRingBuf[iDumRingIndex].fEllipsoidYaw := stFix[PRES_FIX].fEllipsoidYaw;
        stRingBuf[iDumRingIndex].fEllipsoidPitch := stFix[PRES_FIX].fEllipsoidPitch;

        // *  Set the ring buffer's entry for the saccade duration, i.e. the time from the end of the previous
        // *  fixation to the start of the present fixation.
        // *  Note: The saccade duration is the same for all ring index samples of this fixation.
        stRingBuf[iDumRingIndex].iSacDuration := stFix[PRES_FIX].iStartCount - stFix[PREV_FIX].iEndCount - 1;

        // *  Set the ring buffer's entry for the fixation duration, i.e. the time from the start of the present
        // *  fixation to the time indicated by the ring index.
        // *  Note: The fixation duration changes (decreases) for earlier restored points.
        stRingBuf[iDumRingIndex].iFixDuration := stFix[PRES_FIX].iEndCount - iRingPointOffset - stFix[PRES_FIX].iStartCount + 1;
      end;

      // *  Save the fixation end count for use next time this function is called.
      siPreviousFixEndCount := stFix[PRES_FIX].iEndCount;
    end

    // *  Otherwise, if there are not enough good eye samples to declare a real fixation
    else // if (stFix[PRES_FIX].iNEyeFoundSamples < iMinimumFixSamples)
    begin
      // *  Leave the ring buffer alone.  (no code)
    end
  end

  // *  Otherwise, if the present fixation hypothesis has been verified previously,
  else 	// if (stFix[PRES_FIX].bFixationVerified == TRUE)
  begin
    // *  Extend the fixation within the ring buffer.
    // *  Mark all the new samples in the ring buffer since the previous good
    // *  sample, including any missed or out points, as fixating:
    // *  Compute the number of new samples that have gone by since the
    // *  present fixation's last good sample.
    iNNewSamples := iDfCallCount - siPreviousFixEndCount;

    // *  Make sure the number of samples does not exceed the ring-buffer size.
    Assert(iNNewSamples > 0);
    Assert(iNNewSamples <= RING_SIZE);
    if (iNNewSamples > RING_SIZE) then
      iNNewSamples := RING_SIZE;

     // *  Loop backwards through the ring buffer, starting with the current ring index, for the total number of fixation samples.
    for iRingPointOffset := 0 to iNNewSamples - 1 do
    begin
      // *  Compute the ring index of the earlier point.
      iDumRingIndex := iCurrentRingIndex - iRingPointOffset;
      if (iDumRingIndex < 0) then
        Inc(iDumRingIndex, RING_SIZE);

      Assert((iDumRingIndex >= 0) and (iDumRingIndex < RING_SIZE));

      // *  Declare the sample to be fixating at the currently computed fixation point.
      stRingBuf[iDumRingIndex].iEyeMotionState := FIXATING;
      stRingBuf[iDumRingIndex].fXFix := stFix[PRES_FIX].fX;
      stRingBuf[iDumRingIndex].fYFix := stFix[PRES_FIX].fY;
      stRingBuf[iDumRingIndex].fZFix := stFix[PRES_FIX].fZ;
      stRingBuf[iDumRingIndex].fXEllipsoidR := stFix[PRES_FIX].fXEllipsoidR;

      stRingBuf[iDumRingIndex].fYEllipsoidR := stFix[PRES_FIX].fYEllipsoidR;
      stRingBuf[iDumRingIndex].fZEllipsoidR := stFix[PRES_FIX].fZEllipsoidR;
      stRingBuf[iDumRingIndex].fEllipsoidYaw := stFix[PRES_FIX].fEllipsoidYaw;
      stRingBuf[iDumRingIndex].fEllipsoidPitch := stFix[PRES_FIX].fEllipsoidPitch;

      // *  Set the ring buffer's entry for the saccade duration, i.e. the time from
      // *  the end of the previous fixation to the start of the present fixation.
      // *  Note: The saccade duration is the same for all ring index points.
      stRingBuf[iDumRingIndex].iSacDuration := stFix[PRES_FIX].iStartCount - stFix[PREV_FIX].iEndCount - 1;

      // *  Set the ring buffer's entry for the fixation duration, i.e. the time from the start
      // *  of the present fixation to the time indicated by the ring index.
      // *  Note: The fixation duration changes (decreases) for earlier restored points.
      stRingBuf[iDumRingIndex].iFixDuration := stFix[PRES_FIX].iEndCount - iRingPointOffset - stFix[PRES_FIX].iStartCount + 1;
    end;

    // *  Save the fixation end count for use next time this function is called.
    siPreviousFixEndCount := stFix[PRES_FIX].iEndCount;
  end;
end;



procedure TFixFuncClass3dCalcByEllipsoid.UpdateFixationHypothesis(iNewPresOrPrev: Integer;  fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad: Single; iMinimumFixSamples: Integer);
// *  This function updates the argument NewPresOrPrev fixation with the argument gazepoint, checks if there are enough samples to declare that
// *  the eye is now fixating, and if so, declares the appropriate ring buffer entries to be fixating.
// *  The function also makes sure there is no hypothesis for a new fixation.

begin
  // *  Update the argument fixation with the argument gazepoint.
  Inc(stFix[iNewPresOrPrev].iNEyeFoundSamples);
  stFix[iNewPresOrPrev].fXSum := stFix[iNewPresOrPrev].fXSum + fXGaze;
  stFix[iNewPresOrPrev].fYSum := stFix[iNewPresOrPrev].fYSum + fYGaze;
  stFix[iNewPresOrPrev].fZSum := stFix[iNewPresOrPrev].fZSum + fZGaze;
  stFix[iNewPresOrPrev].fX := stFix[iNewPresOrPrev].fXSum / stFix[iNewPresOrPrev].iNEyeFoundSamples;
  stFix[iNewPresOrPrev].fY := stFix[iNewPresOrPrev].fYSum / stFix[iNewPresOrPrev].iNEyeFoundSamples;
  stFix[iNewPresOrPrev].fZ := stFix[iNewPresOrPrev].fZSum / stFix[iNewPresOrPrev].iNEyeFoundSamples;
  stFix[iNewPresOrPrev].iEndCount := iDfCallCount;

  // *  Calculate the new ellipsoid parameters
  CalcEllipsoid(fXLeftEye,fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye,stFix[iNewPresOrPrev].fX, stFix[iNewPresOrPrev].fY, stFix[iNewPresOrPrev].fZ, fAccuracyAngleRad, stFix[iNewPresOrPrev].fXEllipsoidR, stFix[iNewPresOrPrev].fYEllipsoidR, stFix[iNewPresOrPrev].fZEllipsoidR, stFix[iNewPresOrPrev].fEllipsoidYaw, stFix[iNewPresOrPrev].fEllipsoidPitch);

  // *  If updating the present fixation,
  if (iNewPresOrPrev = PRES_FIX) then
  begin

    // *  Reset the number of consecutive gazepoints that have gone outside the present fixation's acceptance ellipsoid.
    iNOutsidePresEllipsoid := 0;

    // *  Test if there are enough samples in the present fixation hypothesis to declare that the eye is actually fixating, and if so declare the
    // *  appropriate ring-buffer samples to be fixating.
    TestPresFixHypAndUpdateRingBuffer(iMinimumFixSamples);

    // *  There is no hypothesis for a new fixation.
    ResetFixationHypothesis(NEW_FIX);

  end;
end;


procedure TFixFuncClass3dCalcByEllipsoid.StartFixationHypothesisAtGazepoint(iNewPresOrPrev: Integer; fXGaze, fYGaze, fZGaze: Single);
// *  This function starts the argument NewPresOrPrev fixation at the argument gazepoint and makes sure there is no new fixation hypothesis.

begin
  // *  Start the present fixation at the argument gazepoint.
  stFix[iNewPresOrPrev].iNEyeFoundSamples := 1;
  stFix[iNewPresOrPrev].fXSum := fXGaze;
  stFix[iNewPresOrPrev].fYSum := fYGaze;
  stFix[iNewPresOrPrev].fZSum := fZGaze;
  stFix[iNewPresOrPrev].fX := fXGaze;
  stFix[iNewPresOrPrev].fY := fYGaze;
  stFix[iNewPresOrPrev].fZ := fZGaze;

  stFix[iNewPresOrPrev].fXEllipsoidR := 0;
  stFix[iNewPresOrPrev].fYEllipsoidR := 0;
  stFix[iNewPresOrPrev].fZEllipsoidR := 0;

  stFix[iNewPresOrPrev].fEllipsoidYaw := 0;
  stFix[iNewPresOrPrev].fEllipsoidPitch := 0;

  stFix[iNewPresOrPrev].iStartCount := iDfCallCount;
  stFix[iNewPresOrPrev].iEndCount := iDfCallCount;
  stFix[iNewPresOrPrev].bFixationVerified := FALSE;

  // * If starting the present fixation,
  if (iNewPresOrPrev = PRES_FIX) then
  begin
    // *  Reset the number of consecutive gazepoints that have gone outside
    // *  the present fixation's acceptance ellipsoid.
    iNOutsidePresEllipsoid := 0;

    // *  Make sure there is no new fixation.
    ResetFixationHypothesis(NEW_FIX);
  end;
end;



procedure TFixFuncClass3dCalcByEllipsoid.MoveNewFixToPresFix;
// * Diese Funktion kopiert die neuen Fixationsdaten in die gegenw�rtige Fixation und l�scht die neue Fixations-Hypothese

begin
   // * L�sche die Anzahl aufeinanderfolgender Blickpunkte, die au�erhalb des aktuellen
   // * Fixations-Akzeptanzbereiches liegen.
   iNOutsidePresEllipsoid := 0;

   // *  Erkl�rt die neue Fixations-Hypothese zur gegenw�rtigen Fixations-Hypothese.
   stFix[PRES_FIX] := stFix[NEW_FIX];

   // *  L�scht NEW_FIX.
   ResetFixationHypothesis(NEW_FIX);
end;


procedure TFixFuncClass3dCalcByEllipsoid.CalcEllipsoid(fXEyeLeft, fYEyeLeft,
  fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight, fXEllipsoidCenter, fYEllipsoidCenter, fZEllipsoidCenter,
  fAccuracyAngleRad: Single; var fXEllipsoidR, fYEllipsoidR, FZEllipsoidR, fEllipsoidYaw, fEllipsoidPitch: Single);

var
    XCycl,YCycl,ZCycl: Single;    // *  position of the cyclopedian eye

    D: Single;                    // *  eye distance
    R: Single;                    // *  distance between cyclopedian eye and current fixation center

begin
  // *  Calculate position of the cyclopedian eye
  XCycl:=round((fXEyeLeft+fXEyeRight)/2);
  YCycl:=round((fYEyeLeft+fYEyeRight)/2);
  ZCycl:=round((fZEyeLeft+fZEyeRight)/2);

  D:=round(sqrt(sqr(fXEyeLeft-fXEyeRight)+sqr(fYEyeLeft-fYEyeRight)+sqr(fZEyeLeft-fZEyeRight)));

  R:=round(sqrt(sqr(XCycl-fXEllipsoidCenter)+sqr(YCycl-fYEllipsoidCenter)+sqr(ZCycl-fZEllipsoidCenter)));


  // *  dimensions of the acceptance ellipsoid
  fXEllipsoidR:=R*fAccuracyAngleRad;
  fYEllipsoidR:=R*fAccuracyAngleRad;
  FZEllipsoidR:=fXEllipsoidR*(R/D);

  fEllipsoidYaw:=+arctan((fXEllipsoidCenter-XCycl)/(fZEllipsoidCenter-ZCycl));      // *  yaw angle, psi is positive if the fixation is located to the right
                                                                                    // *  of the cyclopedian eye

  fEllipsoidPitch:=-arctan((fYEllipsoidCenter-YCycl)/(fZEllipsoidCenter-ZCycl));    // *  pitch angle theta is positive if the fixation is located above
                                                                                    // *  the cyclopedian eye

end;

procedure TFixFuncClass3dCalcByEllipsoid.DeclarePresentFixationComplete(iMinimumFixSamples:Integer);
// *  This function:
// *    a) declares the present fixation to be completed back at stFix[PRES_FIX].iEndCount.
// *    b) moves the present fixation to the prior fixation, and
// *    c) moves the new fixation, if any, to the present fixation.

var
  iRingIndexLastFixSample:Integer;	//* ring index of the present fixation's final (completed) gaze sample
  iDoneNSamplesAgo:Integer;

begin
   // *  Compute how many samples ago the fixation was completed.
   iDoneNSamplesAgo := iDFCallCount - stFix[PRES_FIX].iEndCount;

   Assert(iDoneNSamplesAgo <= iMinimumFixSamples);
   if (iDoneNSamplesAgo > iMinimumFixSamples) then
       iDoneNSamplesAgo := iMinimumFixSamples;

   // *  Compute the ring index corresponding to the present fixation's completion time.
   iRingIndexLastFixSample := iCurrentRingIndex - iDoneNSamplesAgo;
   if (iRingIndexLastFixSample < 0) then
       Inc(iRingIndexLastFixSample, RING_SIZE);

   Assert(iRingIndexLastFixSample >= 0);
   Assert(iRingIndexLastFixSample < RING_SIZE);

   // *  Declare the present fixation to be completed.
   stRingBuf[iRingIndexLastFixSample].iEyeMotionState := FIXATION_COMPLETED;

   // *  Move the present fixation to the previous fixation.
   stFix[PREV_FIX] := stFix[PRES_FIX];

   // *  Move the new fixation data, if any, to the present fixation, reset the new fixation, and check if there
   // *  are enough samples in the new (now present) fixation to declare that the eye is fixating.
   MoveNewFixToPresFix();
end;


procedure TFixFuncClass3dCalcByEllipsoid.InitFixation(iMinimumFixSamplesInit, iMaxMissedSamplesInit, iMaxOutSamplesInit: Integer);
  // *  iMinimumFixSamples = minimum number of gaze samples that can be considered a fixation
  // *  Note: if the input value is less than 3, the function sets it to 3
  // *
  // *  This function clears the previous, present and new fixation hypotheses,
  // *  and it initializes DetectFixation()'s internal ring buffers of prior
  // *  gazepoint data.  InitFixation() should be called prior to a sequence
  // *  of calls to DetectFixation().
  // *

begin
  // *  Set the maximum allowable number of consecutive samples that may go untracked within a fixation.
  iMaxMissedSamples := iMaxMissedSamplesInit;   // original: iMaxMissedSamples := 3;

  // *  Set the maximum allowable number of consecutive samples that may go outside the fixation acceptance ellipsoid.
  iMaxOutSamples := iMaxOutSamplesInit;         // original: iMaxOutSamples := 1;

  // *  Initialize the internal ring buffer.
  iCurrentRingIndex := 0;
  while iCurrentRingIndex < RING_SIZE do

  begin
    stRingBuf[iCurrentRingIndex].iDfCallCount := 0;
    stRingBuf[iCurrentRingIndex].bGazeFound := FALSE;

    stRingBuf[iCurrentRingIndex].fXGaze := 0;
    stRingBuf[iCurrentRingIndex].fYGaze := 0;
    stRingBuf[iCurrentRingIndex].fZGaze := 0;

    stRingBuf[iCurrentRingIndex].fXFix := 0;
    stRingBuf[iCurrentRingIndex].fYFix := 0;
    stRingBuf[iCurrentRingIndex].fZFix := 0;

    stRingBuf[iCurrentRingIndex].fXEllipsoidR := 0;
    stRingBuf[iCurrentRingIndex].fYEllipsoidR := 0;
    stRingBuf[iCurrentRingIndex].fZEllipsoidR := 0;

    stRingBuf[iCurrentRingIndex].fEllipsoidYaw := 0;
    stRingBuf[iCurrentRingIndex].fEllipsoidPitch := 0;

    stRingBuf[iCurrentRingIndex].iEyeMotionState := MOVING;
    stRingBuf[iCurrentRingIndex].iSacDuration := 0;
    stRingBuf[iCurrentRingIndex].iFixDuration := 0;
    Inc(iCurrentRingIndex);
  end;
  iCurrentRingIndex := 0;
  iRingIndexDelay := RING_SIZE - iMinimumFixSamplesInit;

  // *  Set the number of times the DetectFixation() has been called since
  // *  initialization to zero, and initialize the previous fixation end count
  // *  so the first saccade duration will be a legitimate count.
  iDfCallCount := 0;
  stFix[PREV_FIX].iEndCount := 0;

  // *  Reset the present fixation data.
  ResetFixationHypothesis(PRES_FIX);

  // *  Reset the new fixation data.
  ResetFixationHypothesis(NEW_FIX);
end;



function TFixFuncClass3dCalcByEllipsoid.DetectFixation(

                                          // *  INPUT PARAMETERs:

                                          bValidSample: Integer; 		          // *  flag indicating whether or not the image processing algorithm
                                                                              // *    detected booth eyes and computed a valid 3d gazepoint (TRUE/FALSE)

                                          fXLeftEye: Single;                  // *  3D coordinates of the left eye
                                          fYLeftEye: Single;
                                          fZLeftEye: Single;

                                          fXRightEye: Single;                 // *  3D coordinates of the right eye
                                          fYRightEye: Single;
                                          fZRightEye: Single;

                                          fXGaze: Single; 				            // *  3D coordinates of the current gazepoint
                                          fYGaze: Single;
                                          fZGaze: Single;
                                          fAccuracyAngleRad: Single;          // *  threshold for the ellipsoid dimensions related to the fixation distance

                                          iMinimumFixSamples: Integer; 		    // *  minimum number of gaze samples that can be considered a fixation
                                                                              // *    Note: if the input value is less than 3, the function sets it to 3

                                          // * OUTPUT PARAMETERS: delayed gazepoint data with 3D fixation annotations:

                           out            pbValidSampleDelayed: Integer;      // *  bValidSample, iMinimumFixSamples ago

                           out            pfXGazeDelayed,  		                // *  3D coordinates of gazepoint, iMinimumFixSamples ago
                                          pfYGazeDelayed,
                                          pfZGazeDelayed: Single;

                           out            pfXFixDelayed, 			                // *  3D coordinates of fixation point, iMinimumFixSamples ago
                                          pfYFixDelayed,
                                          pfZFixDelayed: Single;

                           out            pfXEllipsoidRDelayed,               // *  3D coordinaties and orientation of the ellipsoid, iMinimumFixSamples ago
                                          pfYEllipsoidRDelayed,
                                          pfZEllipsoidRDelayed: Single;

                           out            pfEllipsoidYawDelayed,              // *    yaw angle
                                          pfEllipsoidPitchDelayed: Single;    // *    pitch angle

                           out            piSacDurationDelayed, 	            // *  duration of the saccade preceeding the preset fixation (samples)
                                          piFixDurationDelayed: Integer): Integer; 	// *  duration of the present fixation (samples)



// *  RETURN VALUES - Eye Motion State:
// *
// *    MOVING               0   The eye was in motion, iMinimumFixSamples ago.
// *    FIXATING             1   The eye was fixating, iMinimumFixSamples ago.
// *    FIXATION_COMPLETED   2   A completed fixation has just been detected, iMinimumFixSamples ago. With respect to the sample that reports
// *                               FIXATION_COMPLETED, the fixation started (iMinimumFixSamples + *piSaccadeDurationDelayed) ago and ended
// *                               iMinimumFixSamples ago.
// *
// *  SUMMARY
// *
// *    This function converts a series of uniformly-sampled (raw) gaze points into a series of variable-duration saccades and fixations.
// *    Fixation analysis may be performed in real time or after the fact.  To allow eye fixation analysis during real-time eyegaze data collection,
// *    the function is designed to be called once per sample.
// *
// *    When the eye is in motion, ie during saccades, the function returns 0 (MOVING).
// *
// *    When the eye is still, ie during fixations, the function returns 1 (FIXATING).
// *
// *    Upon the detected completion of a fixation, the function returns 2 (FIXATION_COMPLETED) and produces:
// *      a) the time duration of the saccade between the last and present eye fixation (eyegaze samples)
// *      b) the time duration of the present, just completed fixation (eyegaze samples)
// *      c) the average x, y and z coordinates of the eye fixation (in user defined units)
// *
// *    Note: Although this function is intended to work in "real time", there is a delay of iMinimumFixSamples in the filter which detects the
// *    motion/fixation condition of the eye.
// *
// *
// *  PRINCIPLE OF OPERATION
// *
// *    This function detects fixations by looking for sequences of gazepoint measurements that remain relatively constant. If a new gazepoint
// *    lies within a ellipsoid region around the running average of an on-going fixation, the fixation is extended to include the new gazepoint.
// *    The dimensions of the acceptance ellipsoid is user specified by setting the value of the function argument fAccuracyAngleRad. This angle
// *    defines the horizontal and vertical radius of the ellipsoid and the depth parameter is calculated related to the fixation distance (for
// *    further information see the comments on the CalcEllipsoid function.) The Ellipsoid is not radially symmetric and has to be oriented (yaw
// *    and pitch) to the user. Therefore a cyclopedian eye is defined between the users right and the left eye.
// *
// *    To accommodate noisy eyegaze measurements, a gazepoint that exceeds the deviation threshold is included in an on-going fixation if the
// *    subsequent gazepoint returns to a position within the threshold.
// *
// *    If a gazepoint is not found, during a blink for example, a fixation is extended if
// *      a) the next legitimate gazepoint measurement falls within the acceptance ellipsoid, and
// *      b) there are less than iMinimumFixSamples of successive missed gazepoints.  Otherwise, the previous fixation is considered to end at
// *         the last good gazepoint measurement.
// *
// *
// *  UNITS OF MEASURE
// *
// *    The gaze position/direction may be expressed in any units (e.g. millimeters, pixels, or radians), but the filter threshold must be
// *    expressed in the same units.
// *
// *  INITIALIZING THE FUNCTION
// *
// *    Prior to analyzing a sequence of gazepoint data, the InitFixation function should be called to clear any previous, present and new
// *    fixations and to initialize the ring buffers of prior gazepoint data.
// *
// *  PROGRAM NOTES
// *
// *    For purposes of describing an ongoing sequence of fixations, fixations in this program are referred to as "previous", "present", and "new".
// *    The present fixation is the one that is going on right now, or, if a new fixation has just started, the present fixation is the one that
// *    just finished.  The previous fixation is the one immediatly preceeding the present one, and a new fixation is the one immediately following
// *    the present one.  Once the present fixation is declared to be completed, the present fixation becomes the previous one, the new fixation
// *    becomes the present one, and there is not yet a new fixation.
// *
// *
// *--------------------------------------------------------------------------------------------------------------------------------------------------------*/



var
  iPastRingIndex: Integer;
  i: Integer;
begin

  // *  Make sure the minimum fix time is at least 3 samples.
  if (iMinimumFixSamples < 3) then
    iMinimumFixSamples := 3;

  // *  Make sure the ring size is large enough to handle the delay.
  Assert(iMinimumFixSamples < RING_SIZE);

  // * Increment the call count, the ring index, and the delayed ring index.
  Inc(iDfCallCount);
  iPastRingIndex := iCurrentRingIndex;
  Inc(iCurrentRingIndex);
  if (iCurrentRingIndex >= RING_SIZE) then
    iCurrentRingIndex := 0;
  iRingIndexDelay := iCurrentRingIndex - iMinimumFixSamples;
  if (iRingIndexDelay < 0) then
    Inc(iRingIndexDelay, RING_SIZE);

  Assert((iCurrentRingIndex >= 0) and (iCurrentRingIndex < RING_SIZE));
  Assert((iRingIndexDelay >= 0) and (iRingIndexDelay < RING_SIZE));

  // * Update the ring buffer of past gazepoints.
  stRingBuf[iCurrentRingIndex].iDfCallCount := iDfCallCount;
  stRingBuf[iCurrentRingIndex].fXGaze := fXGaze;
  stRingBuf[iCurrentRingIndex].fYGaze := fYGaze;
  stRingBuf[iCurrentRingIndex].fZGaze := fZGaze;

  stRingBuf[iCurrentRingIndex].bGazeFound := bValidSample;

  // *  Initially assume the eye is moving.
  // *  Note: These values are updated during the processing of this and subsequent gazepoints.

  stRingBuf[iCurrentRingIndex].iEyeMotionState := MOVING;

  stRingBuf[iCurrentRingIndex].fXFix := -0;
  stRingBuf[iCurrentRingIndex].fYFix := -0;
  stRingBuf[iCurrentRingIndex].fZFix := -0;

  stRingBuf[iCurrentRingIndex].fXEllipsoidR:= -0;
  stRingBuf[iCurrentRingIndex].fYEllipsoidR:= -0;
  stRingBuf[iCurrentRingIndex].fZEllipsoidR:= -0;

  stRingBuf[iCurrentRingIndex].fEllipsoidYaw:= -0;
  stRingBuf[iCurrentRingIndex].fEllipsoidPitch:= -0;

  stRingBuf[iCurrentRingIndex].iFixDuration := 0;

  // *  The following code keeps the saccade duration increasing during non fixation periods.
  // *  If the eye was moving during the last sample,
  if (stRingBuf[iPastRingIndex].iEyeMotionState = MOVING) then
  begin
    // *  Increment the saccade count from the last sample.
    stRingBuf[iCurrentRingIndex].iSacDuration := stRingBuf[iPastRingIndex].iSacDuration + 1;
  end
  // *  Otherwise, if the eye was fixating during the last sample,
  else
  begin
    // * Reset the saccade count to 1, initially assuming this sample will be the first of sample of an upcoming saccade.
    stRingBuf[iCurrentRingIndex].iSacDuration := 1;
  end;

  // *  - - - - - - - - - - - - - Process Tracked Eye  - - - - - - - - - - - - - -

  // *  A) If the eye's gazepoint was successfully measured this sample,
  if (bValidSample = TRUE) then
  begin
    // * A1 B) If a present fixation hypothesis exists,
    if (stFix[PRES_FIX].iNEyeFoundSamples > 0) then
    begin
      // *       B1) Compute the deviation of the gazepoint from the present fixation.
      bGazeInPresFix := IsGazeInFix(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad);

      // *       C) If the gazepoint is within the present fixation's accepatance ellipsoid
      if bGazeInPresFix=TRUE then
      begin
        // *          C1) Update the present fixation hypothesis, test if the fixating is real, and if so, designate the appropriate entries
        // *              in the ring buffer as fixation points.
        UpdateFixationHypothesis(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad, iMinimumFixSamples);
      end

      // *  Otherwise, if the point is outside the present fixation's acceptance ellipsoid
      else // if bGazeInPresFix=FALSE
      begin
        // *          C2) Increment the number of successive gazepoint samples outside the present fixation's acceptance ellipsoid.
        Inc(iNOutsidePresEllipsoid);

        // *          D)  If the number of successive gazepoints outside the present fixation's acceptance circle has not exceeded its maximum,
        if (iNOutsidePresEllipsoid <= iMaxOutSamples) then
        begin
          // *             D1) Incorporate this gazepoint into the NEW fixation hypothesis:
          // *             	    E)     If a new fixation hypothesis has already been started,
          if (stFix[NEW_FIX].iNEyeFoundSamples > 0) then
          begin
            // *                   E1) Check if the the gazepoint is in the new fixation
            bGazeInNewFix := IsGazeInFix(NEW_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad);

            // *                   F) If the new gazepoint falls within the new fix,
            if bGazeInNewFix=TRUE then
            begin
              // *                      F1) 	Update the new fixation hypothesis, check if there are enough samples to declare that the eye is
              // *                      	    fixating,and if so, declare the appropriate ring buffer entries to be fixating.
              UpdateFixationHypothesis(NEW_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad, iMinimumFixSamples);
            end

            // *   Falls der neue Blickort auch au�erhalb der neuen Fixation liegt, �
            else // if (fNewDr > fGazeDeviationThreshold)
            begin
              // *                       F2) Reset the new fixation at this new gazepoint.
              StartFixationHypothesisAtGazepoint(NEW_FIX, fXGaze, fYGaze, fZGaze);
            end;
          end

          // *  Otherwise, If a new fix hypothesis has not been started,
          else // if (stFix[NEW_FIX].iNEyeFoundSamples == 0)
          begin
            // *                E2) Start a new fixation hypothesis at this gazepoint.
            StartFixationHypothesisAtGazepoint(NEW_FIX, fXGaze, fYGaze, fZGaze);
          end;
        end

        // *   Otherwise, if too many successive gazepoint samples have gone outside the present fixation's acceptance circle,
        else // if (iNOutsidePresCircle > iMaxOutSamples)
        begin
          // *             D2) The present fixation hypothesis must either be declared or rejected:
          // *             G) If the present fixation hypothesis has been verified,
          if (stFix[PRES_FIX].bFixationVerified = TRUE) then
          begin
            // *                G1) Declare the present fixation to be completed at the last good sample, move the present fixation to the
            // *                    prior, and move the new fixation to the present.
            DeclarePresentFixationComplete(iMinimumFixSamples);
          end

          // *   Otherwise, if the present fixation does not have enough good gaze samples to qualify as a real fixation,
          else // if (stFix[PRES_FIX].bFixationVerified == FALSE)
          begin
            // *                G2) Reject the present fixation hypothesis by replacing it with the new fixation hypothesis (which may or may
            // *                    not exist at this time).
            MoveNewFixToPresFix();
          end;

          // *             H) If there is a present fixation hypothesis,
          if (stFix[PRES_FIX].iNEyeFoundSamples > 0) then
          begin
            // *                H1) Compute the deviation of the gazepoint from the now present fixation.
            bGazeInPresFix := IsGazeInFix(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad);

            // *                I) If the gazepoint is within the now present fixation's acceptance ellipsoid
            if bGazeInPresFix = TRUE then
            begin
              // *                   I1) Update the present fixation data, check if there are enough samples to declare that the eye is fixating,
              // *                       and if so, declare the appropriate ring buffer entries to be fixating.
              UpdateFixationHypothesis(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad, iMinimumFixSamples);
            end

            // *  Otherwise, if the gazepoint falls outside the present fixation,
            else // if (bGazeInPresFix = FALSE)
            begin
              // *                   I2) Start a new fixation hypothesis at this gazepoint.
              StartFixationHypothesisAtGazepoint(NEW_FIX, fXGaze, fYGaze, fZGaze);
            end;
          end

          // *  Otherwise, if there is no present fixation hypothesis,
          else // if (stFix[PRES_FIX].iNEyeFoundSamples == 0)
          begin
            // *                H2) Start a present fixation at this gazepoint.
            StartFixationHypothesisAtGazepoint(PRES_FIX, fXGaze, fYGaze, fZGaze);
          end;
        end;
      end;
    end

    // * Otherwise, if there is not a present fixation hypothesis going,
    else // if (stFix[PRES_FIX].iNEyeFoundSamples == 0)
    begin
      // *       B2) Start the present fixation hypothesis at the gazepoint and reset the new fixation hypothesis.
      StartFixationHypothesisAtGazepoint(PRES_FIX, fXGaze, fYGaze, fZGaze);
    end;
  end

  // *- - - - - - - - - - - - - Process Untracked Eyes  - - - - - - - - - - - - -

  // * Otherwise, if the eye's gazepoint was not successfully measured this sample,
  else // if (bGazepointFound == FALSE)
  begin
    // *    A2 J) If there is still time to update the present fixation, i.e. if the last good sample in the present fixation occurred within the permissible time gap,
    // *          within the permissible time gap,
    if (iDfCallCount - stFix[PRES_FIX].iEndCount <= iMaxMissedSamples) then
    begin
      // *       J1) No action is to be taken (no code).
    end

    // *  Otherwise, if too much time has passed since the last good gazepoint in the present fixation,
    else // if (iDFCallCount - stFix[PRES_FIX].iEndCount > iMaxMissedSamples)
    begin
      // *       J2) The present fixation hypothesis must be declared complete or rejected:
      // *       K) If the present fixation hypothesis has been verified, as a real fixation,
      if (stFix[PRES_FIX].bFixationVerified = TRUE) then
      begin
        // *          K1) Declare the present fixation to be completed at the last good sample, move the present fixation to the prior,
        // *              and move the new fixation to the present.
        DeclarePresentFixationComplete(iMinimumFixSamples);
      end

      // *  Otherwise, if the present fixation hypothesis is not verified,
      else // if (stFix[PRES_FIX].bFixationVerified == FALSE)
      begin
        // *          K2) Reject the present fixation hypothesis by replacing it with the new fixation hypothesis
       // *               (which may or may not exist at this time).
        MoveNewFixToPresFix();
      end;
    end;
  end;

  // *---------------------------- Pass Data Back ------------------------------*/

  Assert((iRingIndexDelay >= 0) and (iRingIndexDelay < RING_SIZE));

  // * Pass the delayed gazepoint data, with the relevant saccade/fixation data, back to the calling function.

  pbValidSampleDelayed := stRingBuf[iRingIndexDelay].bGazeFound;

  pfXGazeDelayed := stRingBuf[iRingIndexDelay].fXGaze;
  pfYGazeDelayed := stRingBuf[iRingIndexDelay].fYGaze;
  pfZGazeDelayed := stRingBuf[iRingIndexDelay].fZGaze;

  pfXFixDelayed := stRingBuf[iRingIndexDelay].fXFix;
  pfYFixDelayed := stRingBuf[iRingIndexDelay].fYFix;
  pfZFixDelayed := stRingBuf[iRingIndexDelay].fZFix;

  pfXEllipsoidRDelayed := stRingBuf[iRingIndexDelay].fXEllipsoidR;
  pfYEllipsoidRDelayed := stRingBuf[iRingIndexDelay].fYEllipsoidR;
  pfZEllipsoidRDelayed := stRingBuf[iRingIndexDelay].fZEllipsoidR;

  pfEllipsoidYawDelayed := stRingBuf[iRingIndexDelay].fEllipsoidYaw;
  pfEllipsoidPitchDelayed := stringBuf[iRingIndexDelay].fEllipsoidPitch;

  piSacDurationDelayed := stRingBuf[iRingIndexDelay].iSacDuration;
  piFixDurationDelayed := stRingBuf[iRingIndexDelay].iFixDuration;

  // * Return the eye motion/fixation state for the delayed point.
  Result := stRingBuf[iRingIndexDelay].iEyeMotionState;

  ///////////////////////////////////////////////////////////////////////////////
  ///
  /// Global Output Parameters
  ///

  for i := 0 to RING_SIZE do
    gb_stRingBuf[i]:=stRingBuf[i];

  for i := 0 to 2 do
    gb_stFix[i]:=stFix[i];


end;




procedure TFixFuncClass3dCalcByEllipsoid.TestPresentFixationHypothesis(iMinimumFixSamples: Integer);

// * Diese Funktion testet, ob es gen�gend Samples in der gegenw�rtigen Fixationshypothese gibt, um das Auge als
// * 'fixierend� zu deklarieren. Falls eine Fixation l�uft, aktualisiert die Funktion die entsprechenden momentanen und
// * fr�heren Ringpuffereintr�ge, die zur Fixation geh�ren.

var
  iEarlierPointOffset: Integer; 	// * Index-Offset zum jetzigen Ringpufferindex
  iDumRingIndex: Integer; 		    // * Dummy Ringindex

 // * Falls es gen�gend g�ltige Samples in der Fixationshypothese f�r PRES_FIX gibt, um eine reale Fixation zu bestimmen,
 // * ...
begin
  if (stFix[PRES_FIX].iNEyeFoundSamples >= iMinimumFixSamples) then
  begin
    // *    Deklariere das Auge als �fixierend�. Gehe r�ckw�rts durch die letzten iMinimumFixSamples Eintr�ge des
    // *    Ringpuffers inklusive des aktuellen Punktes, �
    for iEarlierPointOffset := 0 to iMinimumFixSamples - 1 do
    begin
      // *    Berechne den Ringindex des fr�heren Zeitpunktes
      iDumRingIndex := iCurrentRingIndex - iEarlierPointOffset;
      if (iDumRingIndex < 0) then
        Inc(iDumRingIndex, RING_SIZE);

      Assert((iDumRingIndex >= 0) and (iDumRingIndex < RING_SIZE));

      // *       Markiere den Punkt als �fixierend� bzw. innerhalb der Fixation.
      stRingBuf[iDumRingIndex].iEyeMotionState := FIXATING;
      stRingBuf[iDumRingIndex].fXFix := stFix[PRES_FIX].fX;
      stRingBuf[iDumRingIndex].fYFix := stFix[PRES_FIX].fY;
      stRingBuf[iDumRingIndex].fZFix := stFix[PRES_FIX].fZ;

      // *       Setze den Ringpuffereintrag f�r die Sakkadendauer.
      // *       Hinweis: Diese ist f�r alle Punkte identisch.
      stRingBuf[iDumRingIndex].iSacDuration := stFix[PRES_FIX].iStartCount - stFix[PREV_FIX].iEndCount - 1;

      // *       Setze den Ringpuffereintrag f�r die Fixationsdauer, z.B. die Zeit zwischen Start der gegenw�rtigen Fixation und
      // *       die durch den Ringindex angegebene Zeit.
      // *       Hinweis: Die Fixationsdauer verringert sich bei fr�her erfassten Punkten innerhalb der Fixation.
      stRingBuf[iDumRingIndex].iFixDuration := stFix[PRES_FIX].iEndCount - iEarlierPointOffset - stFix[PRES_FIX].iStartCount + 1;

    end;

  end;
end;

end.



