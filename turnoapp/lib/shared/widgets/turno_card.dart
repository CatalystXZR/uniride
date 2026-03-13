/**
 *
 * Project: TurnoApp
 *
 * Original Concept: Agustín Puelma, Cristobal Cordova, Carlos Ibarra
 *
 * Software Architecture & Code: Matías Toledo (catalystxzr)
 *
 * Description: Production-grade implementation for UDD carpooling system.
 *
 * Copyright (c) 2026. All rights reserved.
 *
 */

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TurnoCard extends StatelessWidget {
  final String originCommune;
  final String universityName;
  final String campusName;
  final DateTime departureAt;
  final String direction;
  final int seatsAvailable;
  final int seatPrice;
  final VoidCallback? onTap;

  const TurnoCard({
    super.key,
    required this.originCommune,
    required this.universityName,
    required this.campusName,
    required this.departureAt,
    required this.direction,
    required this.seatsAvailable,
    required this.seatPrice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(departureAt);
    final dateStr = DateFormat('EEE d MMM', 'es').format(departureAt);
    final priceStr = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    ).format(seatPrice);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    direction == 'to_campus'
                        ? Icons.school_outlined
                        : Icons.home_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      direction == 'to_campus'
                          ? '$originCommune → $campusName'
                          : '$campusName → $originCommune',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    priceStr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('$dateStr  $timeStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const Spacer(),
                  Icon(
                    Icons.event_seat_outlined,
                    size: 14,
                    color:
                        seatsAvailable > 0 ? Colors.green : Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$seatsAvailable cupo${seatsAvailable == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: seatsAvailable > 0
                          ? Colors.green
                          : Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                universityName,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
