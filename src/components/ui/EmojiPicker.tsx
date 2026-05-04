import React from 'react';
import { View, Text, TouchableOpacity, ScrollView, StyleSheet } from 'react-native';

const EMOJI_LIST = [
  '🍔', '🚗', '🛍️', '🏥', '🎬', '💡', '📚', '🤝', '🎮', '🎁', 
  '💳', '🐾', '🛠️', '💸', '🧡', '📈', '📦', '🏠', '🧹', '👕',
  '✈️', '🏝️', '🚲', '🍿', '🎸', '🎨', '💻', '📱', '🔋', '⚽',
  '🏊', '🧘', '💄', '💍', '🍼', '🧸', '🪴', '☕', '🍕', '🍰'
];

interface EmojiPickerProps {
  onSelect: (emoji: string) => void;
  selectedEmoji?: string;
}

export const EmojiPicker = ({ onSelect, selectedEmoji }: EmojiPickerProps) => {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Pilih Ikon</Text>
      <ScrollView 
        horizontal 
        showsHorizontalScrollIndicator={false} 
        contentContainerStyle={styles.scrollContent}
      >
        {EMOJI_LIST.map((emoji) => (
          <TouchableOpacity
            key={emoji}
            onPress={() => onSelect(emoji)}
            style={[
              styles.emojiItem,
              selectedEmoji === emoji && styles.selectedItem
            ]}
          >
            <Text style={styles.emojiText}>{emoji}</Text>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginVertical: 12,
  },
  title: {
    fontFamily: 'Inter_SemiBold',
    fontSize: 12,
    color: '#71717a',
    textTransform: 'uppercase',
    letterSpacing: 1.5,
    marginBottom: 10,
  },
  scrollContent: {
    gap: 10,
    paddingRight: 20,
  },
  emojiItem: {
    width: 50,
    height: 50,
    borderRadius: 15,
    backgroundColor: '#09090b',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#27272a',
  },
  selectedItem: {
    borderColor: '#10b981',
    backgroundColor: '#10b98110',
  },
  emojiText: {
    fontSize: 24,
  },
});
