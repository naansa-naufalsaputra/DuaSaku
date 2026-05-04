import React from 'react';
import { Skeleton as MotiSkeleton } from 'moti/skeleton';

interface SkeletonProps {
  width?: number | string;
  height?: number | string;
  radius?: number | 'round';
  show?: boolean;
}

export const Skeleton = ({ width, height, radius = 8, show = true }: SkeletonProps) => {
  return (
    <MotiSkeleton
      colorMode="dark"
      width={width as any}
      height={height as any}
      radius={radius as any}
      show={show}
      colors={['#18181b', '#27272a', '#18181b']}
    />
  );
};
