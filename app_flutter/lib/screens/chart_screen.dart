import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ChartScreen extends StatelessWidget {

  final List<double> pitchData;
  final List<double> rollData;

  const ChartScreen({
    super.key,
    required this.pitchData,
    required this.rollData,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.white,

      appBar: AppBar(

        title: const Text(
          "Realtime MPU6050",
        ),

        backgroundColor: Colors.white,

        elevation: 0,
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Container(

          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius:
                BorderRadius.circular(24),

            boxShadow: [

              BoxShadow(
                color:
                    Colors.black.withOpacity(0.05),

                blurRadius: 10,
              ),
            ],
          ),

          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              const Text(

                "Pitch / Roll Live",

                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(

                "Points: ${pitchData.length}",

                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(

                child: LineChart(

                  LineChartData(

                    minY: -180,
                    maxY: 180,

                    clipData: FlClipData.all(),

                    gridData: FlGridData(
                      show: true,
                    ),

                    borderData: FlBorderData(
                      show: false,
                    ),

                    titlesData: FlTitlesData(

                      topTitles: AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles: false,
                        ),
                      ),

                      rightTitles: AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles: false,
                        ),
                      ),
                    ),

                    lineBarsData: [

                      /// PITCH
                      LineChartBarData(

                        spots: List.generate(

                          pitchData.length,

                          (i) => FlSpot(
                            i.toDouble(),
                            pitchData[i],
                          ),
                        ),

                        color: Colors.green,

                        isCurved: true,

                        curveSmoothness: 0.3,

                        barWidth: 4,

                        isStrokeCapRound: true,

                        dotData: FlDotData(
                          show: false,
                        ),
                      ),

                      /// ROLL
                      LineChartBarData(

                        spots: List.generate(

                          rollData.length,

                          (i) => FlSpot(
                            i.toDouble(),
                            rollData[i],
                          ),
                        ),

                        color: Colors.blue,

                        isCurved: true,

                        curveSmoothness: 0.3,

                        barWidth: 4,

                        isStrokeCapRound: true,

                        dotData: FlDotData(
                          show: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(

                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,

                children: [

                  Row(
                    children: [

                      Container(
                        width: 14,
                        height: 14,
                        decoration:
                            BoxDecoration(
                          color: Colors.green,
                          borderRadius:
                              BorderRadius.circular(4),
                        ),
                      ),

                      const SizedBox(width: 8),

                      const Text(
                        "Pitch",
                      ),
                    ],
                  ),

                  Row(
                    children: [

                      Container(
                        width: 14,
                        height: 14,
                        decoration:
                            BoxDecoration(
                          color: Colors.blue,
                          borderRadius:
                              BorderRadius.circular(4),
                        ),
                      ),

                      const SizedBox(width: 8),

                      const Text(
                        "Roll",
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}