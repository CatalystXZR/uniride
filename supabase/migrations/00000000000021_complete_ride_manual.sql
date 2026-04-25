/**
 * Complete ride manually - for driver to end ride without passenger confirmation
 */
CREATE OR REPLACE FUNCTION public.complete_ride_manual(p_ride_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_ride record;
  v_booking record;
  v_passenger uuid;
  v_amount int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Sesion requerida' USING ERRCODE = 'P0001';
  END IF;

  -- Get ride info
  SELECT * INTO v_ride FROM rides WHERE id = p_ride_id AND driver_id = v_user;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ride no encontrado o no eres el conductor' USING ERRCODE = 'P0002';
  END IF;

  IF v_ride.status != 'active' THEN
    RAISE EXCEPTION 'El ride no esta activo' USING ERRCODE = 'P0005';
  END IF;

  -- Get accepted booking
  SELECT * INTO v_booking 
  FROM bookings 
  WHERE ride_id = p_ride_id 
    AND status = 'reserved' 
    AND dispatch_status IN ('in_progress', 'completed')
  LIMIT 1;

  IF NOT FOUND THEN
    -- No active booking, just complete the ride
    UPDATE rides SET status = 'completed', completed_at = now() WHERE id = p_ride_id;
    RETURN;
  END IF;

  v_passenger := v_booking.passenger_id;
  v_amount := v_booking.amount_total;

  -- Complete the booking
  UPDATE bookings 
  SET status = 'completed', 
      dispatch_status = 'completed',
      completed_at = now()
  WHERE id = v_booking.id;

  -- Release held funds to driver wallet
  UPDATE wallets
  SET balance_held = balance_held - v_amount,
      balance_available = balance_available + v_amount,
      updated_at = now()
  WHERE user_id = v_passenger
    AND balance_held >= v_amount;

  -- Create transaction for driver payment
  INSERT INTO transactions (user_id, booking_id, type, amount, metadata)
  VALUES (
    v_passenger,
    v_booking.id,
    'ride_complete',
    v_amount,
    jsonb_build_object('ride_id', p_ride_id, 'driver_id', v_user)
  );

  -- Complete the ride
  UPDATE rides 
  SET status = 'completed', 
      completed_at = now()
  WHERE id = p_ride_id;
END $$;

GRANT EXECUTE ON FUNCTION public.complete_ride_manual(uuid) TO authenticated;