import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const adjectives = [
  'Premium', 'Ultra-Slim', 'Compact', 'Wireless', 'Professional',
  'Advanced', 'Portable', 'Smart', 'Ergonomic', 'Lightweight',
  'Heavy-Duty', 'High-Performance', 'Eco-Friendly', 'Deluxe', 'Classic',
  'Modern', 'Vintage', 'Sleek', 'Rugged', 'Innovative',
  'Minimalist', 'Industrial', 'Luxury', 'Essential', 'Ultimate',
  'Dynamic', 'Precision', 'Elite', 'Turbo', 'Flex',
  'Quiet', 'Rapid', 'Crystal', 'Nano', 'Mega',
  'Digital', 'Hybrid', 'Solar', 'Thermal', 'Magnetic',
  'Titanium', 'Carbon', 'Ceramic', 'Bamboo', 'Silicone',
  'Foldable', 'Adjustable', 'Waterproof', 'Shockproof', 'Multi-Purpose',
  'Travel', 'Studio', 'Gaming', 'Outdoor', 'Office',
];

const nouns = [
  'Headphones', 'Laptop Stand', 'Bluetooth Speaker', 'Keyboard', 'Mouse',
  'Webcam', 'Monitor Light', 'Desk Lamp', 'USB Hub', 'Charger',
  'Power Bank', 'Phone Case', 'Tablet Sleeve', 'Cable Organizer', 'Mousepad',
  'Microphone', 'Ring Light', 'Tripod', 'Stylus Pen', 'Screen Protector',
  'Docking Station', 'External Drive', 'Flash Drive', 'Card Reader', 'Router',
  'Earbuds', 'Headset', 'Soundbar', 'Subwoofer', 'Amplifier',
  'Smartwatch Band', 'Fitness Tracker', 'VR Headset', 'Controller', 'Joystick',
  'Projector', 'Streaming Device', 'Smart Plug', 'LED Strip', 'Desk Fan',
  'Air Purifier', 'Humidifier', 'Thermometer', 'Scale', 'Timer',
  'Backpack', 'Messenger Bag', 'Laptop Bag', 'Tool Kit', 'Cleaning Kit',
  'Notebook', 'Planner', 'Whiteboard', 'Pen Set', 'Desk Organizer',
];

const descriptionTemplates = [
  'A high-quality {adj} {noun} designed for everyday use and maximum comfort.',
  'Experience superior performance with this {adj} {noun} built to last.',
  'This {adj} {noun} combines style and functionality for modern professionals.',
  'Upgrade your setup with this reliable {adj} {noun} at an incredible value.',
  'The perfect {adj} {noun} for those who demand quality and durability.',
  'Enjoy seamless connectivity and design with this {adj} {noun} for any workspace.',
  'A must-have {adj} {noun} that delivers exceptional results every single time.',
  'Crafted with precision, this {adj} {noun} elevates your daily productivity effortlessly.',
  'Discover the difference with this {adj} {noun} engineered for peak performance.',
  'This versatile {adj} {noun} is ideal for both home and office environments.',
  'Stay ahead of the curve with this cutting-edge {adj} {noun} solution.',
  'Compact and powerful, this {adj} {noun} fits perfectly into any lifestyle.',
  'Transform your workflow with this intuitive and elegant {adj} {noun} design.',
  'Built for reliability, this {adj} {noun} handles any challenge with ease.',
  'The ultimate {adj} {noun} for tech enthusiasts who value innovation and style.',
];

function randomItem<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

async function main() {
  console.log('Seeding 1,000 products...');

  const BATCH_SIZE = 100;
  const TOTAL = 1000;

  for (let batch = 0; batch < TOTAL / BATCH_SIZE; batch++) {
    const products = [];

    for (let i = 0; i < BATCH_SIZE; i++) {
      const id = batch * BATCH_SIZE + i + 1;
      const adj = randomItem(adjectives);
      const noun = randomItem(nouns);
      const name = `${adj} ${noun}`;
      const template = randomItem(descriptionTemplates);
      const description = template
        .replace('{adj}', adj.toLowerCase())
        .replace('{noun}', noun.toLowerCase());
      const price = Math.round(Math.random() * 49000 + 1000) / 100;
      const image = `https://picsum.photos/400/400?random=${id}`;

      products.push({ name, description, price, image });
    }

    await prisma.product.createMany({ data: products });
    console.log(`  Batch ${batch + 1}/${TOTAL / BATCH_SIZE} inserted (${(batch + 1) * BATCH_SIZE} products)`);
  }

  console.log('Seeding complete!');
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
