import React from 'react';
import { FlexWidget, TextWidget } from 'react-native-android-widget';

interface DuaSakuWidgetProps {
  currentAmount: number;
  targetAmount: number;
  budgetName: string;
}

export function DuaSakuWidget({ currentAmount, targetAmount, budgetName }: DuaSakuWidgetProps) {
  const percentage = targetAmount > 0 ? Math.min((currentAmount / targetAmount) * 100, 100) : 0;
  
  return (
    <FlexWidget
      style={{
        height: 'match_parent',
        width: 'match_parent',
        backgroundColor: '#18181b', // surface
        borderRadius: 16,
        padding: 16,
        flexDirection: 'column',
        justifyContent: 'center',
      }}
    >
      <TextWidget
        text={budgetName || "Sisa Budget"}
        style={{
          fontSize: 14,
          color: '#a1a1aa',
          marginBottom: 4,
        }}
      />
      <TextWidget
        text={`Rp ${currentAmount.toLocaleString('id-ID')}`}
        style={{
          fontSize: 24,
          color: '#fafafa',
          fontWeight: 'bold',
          marginBottom: 12,
        }}
      />
      
      {/* Progress Bar Background */}
      <FlexWidget
        style={{
          height: 8,
          width: 'match_parent',
          backgroundColor: '#27272a',
          borderRadius: 4,
        }}
      >
        {/* Progress Bar Fill */}
        <FlexWidget
          style={{
            height: 8,
            width: `${percentage}%` as any,
            backgroundColor: percentage >= 80 ? '#ef4444' : '#10b981',
            borderRadius: 4,
          }}
        />
      </FlexWidget>
      
      <FlexWidget style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 8 }}>
        <TextWidget
          text={`${percentage.toFixed(0)}% terpakai`}
          style={{ fontSize: 12, color: '#a1a1aa' }}
        />
        <TextWidget
          text={`Total: Rp ${targetAmount.toLocaleString('id-ID')}`}
          style={{ fontSize: 12, color: '#a1a1aa' }}
        />
      </FlexWidget>
    </FlexWidget>
  );
}
