import React from 'react';
import { View, Text } from 'react-native';
import { BarChart } from 'react-native-gifted-charts';

export default function ExpenseChart() {
  // Dummy data, nanti bisa diganti data asli dari Supabase
  const barData = [
    { value: 250000, label: 'Sen', frontColor: '#10b981' },
    { value: 500000, label: 'Sel', frontColor: '#2dd4bf' },
    { value: 150000, label: 'Rab', frontColor: '#10b981' },
    { value: 750000, label: 'Kam', frontColor: '#10b981' },
    { value: 300000, label: 'Jum', frontColor: '#10b981' },
  ];

  return (
    <View className="p-4 bg-surface-container rounded-3xl m-4 border border-border">
      <Text className="text-foreground text-lg font-h2 mb-4">Pengeluaran Minggu Ini</Text>
      <BarChart
        data={barData}
        barWidth={22}
        noOfSections={3}
        barBorderRadius={6}
        frontColor="#10b981"
        yAxisThickness={0}
        xAxisThickness={0}
        hideRules
        yAxisTextStyle={{ color: '#a1a1aa', fontSize: 10 }}
        xAxisLabelTextStyle={{ color: '#a1a1aa', textAlign: 'center', fontSize: 10 }}
        width={280}
        height={180}
      />
    </View>
  );
}
